function [halos, galaxies] = find_halos_and_galaxies(rho, params)
%FIND_HALOS_AND_GALAXIES  Very simplified halo finder and HOD galaxy filler.
%
% This is not a replacement for FoF, spherical overdensity, ROCKSTAR, or
% SUBFIND. It finds high-density local maxima on the final PM grid and
% assigns toy galaxies with a simple HOD-like rule.

N = size(rho,1);
Lbox = params.Lbox;
dx = Lbox / N;

rho_s = gaussian_smooth_periodic(rho, 1.2);
meanrho = mean(rho_s(:));
stdrho  = std(rho_s(:));

threshold = meanrho + params.halo_threshold_sigma * stdrho;

is_peak = rho_s > threshold;
for di = -1:1
    for dj = -1:1
        for dk = -1:1
            if di == 0 && dj == 0 && dk == 0
                continue;
            end
            is_peak = is_peak & (rho_s >= circshift(rho_s, [di dj dk]));
        end
    end
end

peak_idx = find(is_peak);
[~,ord] = sort(rho_s(peak_idx), 'descend');
peak_idx = peak_idx(ord);

% Enforce a minimum periodic separation between accepted peaks.
accepted = [];
accepted_ijk = zeros(0,3);

for n = 1:numel(peak_idx)
    [ii,jj,kk] = ind2sub([N N N], peak_idx(n));
    cand = [ii jj kk];

    if isempty(accepted)
        keep = true;
    else
        d = abs(accepted_ijk - cand);
        d = min(d, N - d);     % periodic grid distance
        dist = sqrt(sum(d.^2,2));
        keep = all(dist >= params.halo_min_separation);
    end

    if keep
        accepted(end+1,1) = peak_idx(n); %#ok<AGROW>
        accepted_ijk(end+1,:) = cand; %#ok<AGROW>
    end

    if numel(accepted) >= params.max_halos
        break;
    end
end

Nh = numel(accepted);

halos = struct();
halos.x = zeros(Nh,1);
halos.y = zeros(Nh,1);
halos.z = zeros(Nh,1);
halos.grid_i = zeros(Nh,1);
halos.grid_j = zeros(Nh,1);
halos.grid_k = zeros(Nh,1);
halos.peak_density = zeros(Nh,1);
halos.mass_msun_h = zeros(Nh,1);
halos.radius_mpc_h = zeros(Nh,1);

rho_crit = 2.775e11; % Msun h^2 / Mpc^3
Mcell = params.Omega_m * rho_crit * dx^3; % Msun/h per mean-density cell

for h = 1:Nh
    [ii,jj,kk] = ind2sub([N N N], accepted(h));

    halos.grid_i(h) = ii;
    halos.grid_j(h) = jj;
    halos.grid_k(h) = kk;

    halos.x(h) = (ii - 0.5) * dx;
    halos.y(h) = (jj - 0.5) * dx;
    halos.z(h) = (kk - 0.5) * dx;

    halos.peak_density(h) = rho_s(ii,jj,kk) / meanrho;
    halos.radius_mpc_h(h) = params.halo_radius_cells * dx;

    aperture_sum = aperture_density_sum(rho, ii,jj,kk, params.halo_radius_cells);
    halos.mass_msun_h(h) = (aperture_sum / mean(rho(:))) * Mcell;
end

% ---- Toy HOD galaxies ----
gx = [];
gy = [];
gz = [];
gHalo = [];
gLum = [];
gType = {};

for h = 1:Nh
    M = halos.mass_msun_h(h);
    if M < params.Mmin_galaxy
        continue;
    end

    Nsat = floor((M / params.M1_satellite)^params.hod_alpha);
    Ngal = 1 + max(0, Nsat);
    Ngal = min(Ngal, params.max_galaxies_per_halo);

    for q = 1:Ngal
        if q == 1
            jitter = [0 0 0];
            galType = 'central';
        else
            % Satellites scatter inside the halo aperture.
            r = halos.radius_mpc_h(h) * rand()^(1/3);
            mu = 2*rand() - 1;
            phi = 2*pi*rand();
            jitter = r * [sqrt(1-mu^2)*cos(phi), sqrt(1-mu^2)*sin(phi), mu];
            galType = 'satellite';
        end

        gx(end+1,1) = mod(halos.x(h) + jitter(1), Lbox); %#ok<AGROW>
        gy(end+1,1) = mod(halos.y(h) + jitter(2), Lbox); %#ok<AGROW>
        gz(end+1,1) = mod(halos.z(h) + jitter(3), Lbox); %#ok<AGROW>
        gHalo(end+1,1) = h; %#ok<AGROW>
        gLum(end+1,1) = (M / params.Mmin_galaxy)^0.35; %#ok<AGROW>
        gType{end+1,1} = galType; %#ok<AGROW>
    end
end

galaxies = struct();
galaxies.x = gx;
galaxies.y = gy;
galaxies.z = gz;
galaxies.host_halo = gHalo;
galaxies.relative_luminosity = gLum;
galaxies.type = gType;

fprintf('Halo finder: %d halos, %d toy galaxies.\n', Nh, numel(gx));

end

% ======================================================================

function s = aperture_density_sum(rho, ic,jc,kc, radius)
%Aperture sum inside a periodic spherical grid aperture.

N = size(rho,1);
s = 0;

for di = -radius:radius
    for dj = -radius:radius
        for dk = -radius:radius
            if di^2 + dj^2 + dk^2 <= radius^2
                ii = mod(ic + di - 1, N) + 1;
                jj = mod(jc + dj - 1, N) + 1;
                kk = mod(kc + dk - 1, N) + 1;
                s = s + rho(ii,jj,kk);
            end
        end
    end
end

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
