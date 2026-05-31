function [x,y,z,px,py,pz,rho,delta] = particle_mesh_step(x,y,z,px,py,pz,a,da,params)
%PARTICLE_MESH_STEP  One Particle-Mesh KDK-like step in scale factor.
%
% This function performs:
%   particle -> mesh density by CIC
%   mesh density -> potential by FFT Poisson solve
%   potential -> mesh acceleration field
%   mesh acceleration -> particle acceleration by CIC interpolation
%   kick/drift update in comoving coordinates

Ngrid = params.Ngrid;
Lbox  = params.Lbox;

rho = cic_deposit(x,y,z,Ngrid,Lbox);
delta = rho ./ mean(rho(:)) - 1.0;

[gx,gy,gz] = solve_pm_force(delta, a, params);

fx = cic_interp(gx,x,y,z,Lbox);
fy = cic_interp(gy,x,y,z,Lbox);
fz = cic_interp(gz,x,y,z,Lbox);

E = E_of_a(a, params);

% A simplified scale-factor leapfrog. Variables px,py,pz are momentum-like.
px = px + da * fx ./ max(a*E, eps);
py = py + da * fy ./ max(a*E, eps);
pz = pz + da * fz ./ max(a*E, eps);

x = x + da * px ./ max(a^3 * E, eps);
y = y + da * py ./ max(a^3 * E, eps);
z = z + da * pz ./ max(a^3 * E, eps);

x = mod(x, Lbox);
y = mod(y, Lbox);
z = mod(z, Lbox);

end

% ======================================================================

function rho = cic_deposit(x,y,z,N,Lbox)
%CIC_DEPOSIT  Periodic Cloud-in-Cell particle mass assignment.

dx = Lbox / N;

u = x/dx + 1;
v = y/dx + 1;
w = z/dx + 1;

i0 = floor(u); j0 = floor(v); k0 = floor(w);
tx = u - i0; ty = v - j0; tz = w - k0;

i0 = mod(i0-1, N) + 1;
j0 = mod(j0-1, N) + 1;
k0 = mod(k0-1, N) + 1;

i1 = mod(i0, N) + 1;
j1 = mod(j0, N) + 1;
k1 = mod(k0, N) + 1;

rho = zeros(N,N,N);

add_weight(i0,j0,k0, (1-tx).*(1-ty).*(1-tz));
add_weight(i1,j0,k0, tx    .*(1-ty).*(1-tz));
add_weight(i0,j1,k0, (1-tx).*ty    .*(1-tz));
add_weight(i1,j1,k0, tx    .*ty    .*(1-tz));
add_weight(i0,j0,k1, (1-tx).*(1-ty).*tz);
add_weight(i1,j0,k1, tx    .*(1-ty).*tz);
add_weight(i0,j1,k1, (1-tx).*ty    .*tz);
add_weight(i1,j1,k1, tx    .*ty    .*tz);

    function add_weight(ii,jj,kk,ww)
        ind = sub2ind([N N N], ii, jj, kk);
        rho(:) = rho(:) + accumarray(ind, ww, [N^3 1], @sum, 0);
    end

end

function val = cic_interp(field, x, y, z, Lbox)
%CIC_INTERP  Periodic Cloud-in-Cell interpolation from mesh to particles.

N = size(field,1);
dx = Lbox / N;

u = x/dx + 1;
v = y/dx + 1;
w = z/dx + 1;

i0 = floor(u); j0 = floor(v); k0 = floor(w);
tx = u - i0; ty = v - j0; tz = w - k0;

i0 = mod(i0-1, N) + 1;
j0 = mod(j0-1, N) + 1;
k0 = mod(k0-1, N) + 1;

i1 = mod(i0, N) + 1;
j1 = mod(j0, N) + 1;
k1 = mod(k0, N) + 1;

c000 = field(sub2ind([N N N], i0,j0,k0));
c100 = field(sub2ind([N N N], i1,j0,k0));
c010 = field(sub2ind([N N N], i0,j1,k0));
c110 = field(sub2ind([N N N], i1,j1,k0));
c001 = field(sub2ind([N N N], i0,j0,k1));
c101 = field(sub2ind([N N N], i1,j0,k1));
c011 = field(sub2ind([N N N], i0,j1,k1));
c111 = field(sub2ind([N N N], i1,j1,k1));

val = c000.*(1-tx).*(1-ty).*(1-tz) + ...
      c100.*tx    .*(1-ty).*(1-tz) + ...
      c010.*(1-tx).*ty    .*(1-tz) + ...
      c110.*tx    .*ty    .*(1-tz) + ...
      c001.*(1-tx).*(1-ty).*tz + ...
      c101.*tx    .*(1-ty).*tz + ...
      c011.*(1-tx).*ty    .*tz + ...
      c111.*tx    .*ty    .*tz;

end

function [gx,gy,gz] = solve_pm_force(delta, a, params)
%SOLVE_PM_FORCE  Solve Poisson equation with FFT and return force field.

N = size(delta,1);
Lbox = params.Lbox;

[kx,ky,kz,k2] = make_kgrid(N,Lbox);
delta_k = fftn(delta);

k2safe = k2;
k2safe(k2safe == 0) = Inf;

% Poisson: grad^2 Phi = delta in code units.
% Force: g = -grad Phi.
phi_k = -delta_k ./ k2safe;
phi_k(k2 == 0) = 0;

normfac = params.force_boost * 1.5 * params.Omega_m / max(a, eps);

gx = normfac * real(ifftn(-1i * kx .* phi_k));
gy = normfac * real(ifftn(-1i * ky .* phi_k));
gz = normfac * real(ifftn(-1i * kz .* phi_k));

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

function E = E_of_a(a, params)
%E_OF_A  Dimensionless Hubble parameter H(a)/H0 for flat Lambda-CDM.
E = sqrt(params.Omega_m./a.^3 + params.Omega_L);
end
