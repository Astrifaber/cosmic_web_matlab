function webtype = visualize_cosmic_web(rho, halos, galaxies, params, a)
%VISUALIZE_COSMIC_WEB  Plot density, halos, galaxies, and cosmic-web classes.
%
% webtype values:
%   0 = void
%   1 = sheet
%   2 = filament
%   3 = cluster/node

if nargin < 5
    a = 1.0;
end

N = size(rho,1);
Lbox = params.Lbox;
zred = 1/a - 1;

delta = rho ./ mean(rho(:)) - 1.0;
webtype = classify_web(delta, params);

mid = round(N/2);
xaxis = linspace(0,Lbox,N);

figure('Color','w','Name','Cosmic web summary');

subplot(2,2,1);
imagesc(xaxis, xaxis, log10(1 + max(delta(:,:,mid), -0.95)));
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('Mpc/h'); ylabel('Mpc/h');
title(sprintf('Density slice, z = %.2f', zred));

subplot(2,2,2);
imagesc(xaxis, xaxis, webtype(:,:,mid));
axis image; set(gca,'YDir','normal'); colorbar;
xlabel('Mpc/h'); ylabel('Mpc/h');
title('Cosmic web class: 0 void, 1 sheet, 2 filament, 3 node');

subplot(2,2,3);
if ~isempty(halos.x)
    scatter3(halos.x, halos.y, halos.z, 16, log10(max(halos.mass_msun_h,1)), 'filled');
end
axis equal; xlim([0 Lbox]); ylim([0 Lbox]); zlim([0 Lbox]);
grid on; colorbar;
xlabel('x Mpc/h'); ylabel('y Mpc/h'); zlabel('z Mpc/h');
title('Halo candidates');

subplot(2,2,4);
if ~isempty(galaxies.x)
    ms = 4 + 8 * galaxies.relative_luminosity / max(galaxies.relative_luminosity);
    scatter3(galaxies.x, galaxies.y, galaxies.z, ms, galaxies.relative_luminosity, 'filled');
end
axis equal; xlim([0 Lbox]); ylim([0 Lbox]); zlim([0 Lbox]);
grid on; colorbar;
xlabel('x Mpc/h'); ylabel('y Mpc/h'); zlabel('z Mpc/h');
title('Toy galaxies from HOD');

drawnow;

end

% ======================================================================

function webtype = classify_web(delta, params)
%CLASSIFY_WEB  Tidal-tensor cosmic web classifier.

N = size(delta,1);
Lbox = params.Lbox;

delta_s = gaussian_smooth_periodic(delta, params.web_smooth_sigma_cells);

[kx,ky,kz,k2] = make_kgrid(N,Lbox);

delta_k = fftn(delta_s);
k2safe = k2;
k2safe(k2safe == 0) = Inf;

phi_k = -delta_k ./ k2safe;
phi_k(k2 == 0) = 0;

% T_ij = d_i d_j Phi.
Txx = real(ifftn(-kx.*kx .* phi_k));
Tyy = real(ifftn(-ky.*ky .* phi_k));
Tzz = real(ifftn(-kz.*kz .* phi_k));
Txy = real(ifftn(-kx.*ky .* phi_k));
Txz = real(ifftn(-kx.*kz .* phi_k));
Tyz = real(ifftn(-ky.*kz .* phi_k));

lambda_th = params.web_lambda_threshold;

webtype = zeros(N,N,N,'uint8');

% Loop is acceptable for N=64. For N=128 this is slower but still clear.
for idx = 1:numel(delta)
    T = [Txx(idx), Txy(idx), Txz(idx); ...
         Txy(idx), Tyy(idx), Tyz(idx); ...
         Txz(idx), Tyz(idx), Tzz(idx)];
    lam = eig(T);
    webtype(idx) = uint8(sum(lam > lambda_th));
end

end

function [kx,ky,kz,k2] = make_kgrid(N, Lbox)
%MAKE_KGRID  FFT-compatible wavenumber grid.

if mod(N,2) == 0
    kk = [0:(N/2) (-N/2+1):-1];
else
    kk = [0:((N-1)/2) (-(N-1)/2):-1];
end

k1 = (2*pi/Lbox) * kk;
[kx,ky,kz] = ndgrid(k1,k1,k1);
k2 = kx.^2 + ky.^2 + kz.^2;

end

function out = gaussian_smooth_periodic(field, sigma)
%GAUSSIAN_SMOOTH_PERIODIC  Periodic separable Gaussian smoothing.

radius = max(1, ceil(3*sigma));
x = -radius:radius;
ker = exp(-0.5*(x/sigma).^2);
ker = ker / sum(ker);

out = field;

tmp = zeros(size(out));
for n = 1:numel(ker)
    shift = x(n);
    tmp = tmp + ker(n) * circshift(out, [shift 0 0]);
end
out = tmp;

tmp = zeros(size(out));
for n = 1:numel(ker)
    shift = x(n);
    tmp = tmp + ker(n) * circshift(out, [0 shift 0]);
end
out = tmp;

tmp = zeros(size(out));
for n = 1:numel(ker)
    shift = x(n);
    tmp = tmp + ker(n) * circshift(out, [0 0 shift]);
end
out = tmp;

end
