function [x,y,z,px,py,pz,delta0] = make_initial_conditions(params)
%MAKE_INITIAL_CONDITIONS  Generate Zel'dovich-like initial conditions.
%
% Output particle coordinates are comoving positions in [0, Lbox).
% px, py, pz are dimensionless comoving momentum-like variables used by
% particle_mesh_step.m.

rng(params.random_seed);

Ngrid = params.Ngrid;
Np1D  = params.Np1D;
Lbox  = params.Lbox;
a     = params.ai;
dxp   = Lbox / Np1D;

% ---- 1. Build a Gaussian random density field in Fourier space ----
[kx,ky,kz,k2,kmod] = make_kgrid(Ngrid, Lbox);

Pk = linear_power_shape(kmod, params);
Pk(kmod == 0) = 0;

white = randn(Ngrid,Ngrid,Ngrid) + 1i*randn(Ngrid,Ngrid,Ngrid);
delta_k = white .* sqrt(Pk);

% Enforce a real spatial field by simply taking the real part after ifftn.
% For a pedagogical toy model this is adequate; precision IC generators
% should explicitly impose Hermitian symmetry and 2LPT corrections.
delta_raw = real(ifftn(delta_k));
delta_raw = delta_raw - mean(delta_raw(:));
delta_raw = delta_raw / std(delta_raw(:));
delta0 = params.initial_delta_rms * delta_raw;

delta_k = fftn(delta0);

% ---- 2. Zel'dovich displacement field: s_k = -i k delta_k / k^2 ----
k2safe = k2;
k2safe(k2safe == 0) = Inf;

sx = real(ifftn(-1i * kx .* delta_k ./ k2safe));
sy = real(ifftn(-1i * ky .* delta_k ./ k2safe));
sz = real(ifftn(-1i * kz .* delta_k ./ k2safe));

% Normalize displacement amplitude to a stable, visible level.
rms_disp = sqrt(mean(sx(:).^2 + sy(:).^2 + sz(:).^2));
target_rms_disp = params.initial_displacement_cells * dxp;
scale = target_rms_disp / max(rms_disp, eps);

sx = scale * sx;
sy = scale * sy;
sz = scale * sz;

% ---- 3. Place particles on a lattice and interpolate displacements ----
grid1 = ((0:Np1D-1) + 0.5) * dxp;
[qx,qy,qz] = ndgrid(grid1, grid1, grid1);
qx = qx(:); qy = qy(:); qz = qz(:);

sxp = cic_interp_grid(sx, qx, qy, qz, Lbox);
syp = cic_interp_grid(sy, qx, qy, qz, Lbox);
szp = cic_interp_grid(sz, qx, qy, qz, Lbox);

x = mod(qx + sxp, Lbox);
y = mod(qy + syp, Lbox);
z = mod(qz + szp, Lbox);

% Growing-mode velocity approximation.
% If D(a) approximately scales as a at high z, dx/da ~ displacement/a.
E = E_of_a(a, params);
px = a^2 * E * sxp;
py = a^2 * E * syp;
pz = a^2 * E * szp;

end

% ======================================================================

function Pk = linear_power_shape(k, params)
%LINEAR_POWER_SHAPE  Simple BBKS-like CDM transfer shape.
%
% k is in h/Mpc if Lbox is in Mpc/h. This is a shape model only. The
% amplitude is normalized later by params.initial_delta_rms.

ns = params.ns;
Gamma = params.Omega_m * params.h;

q = k ./ max(Gamma, eps);
T = ones(size(k));

mask = q > 0;
qm = q(mask);

% BBKS transfer function.
L0 = log(1 + 2.34*qm) ./ (2.34*qm);
C0 = (1 + 3.89*qm + (16.1*qm).^2 + (5.46*qm).^3 + (6.71*qm).^4).^(-0.25);
T(mask) = L0 .* C0;

Pk = (k.^ns) .* (T.^2);
Pk(~isfinite(Pk)) = 0;
Pk(k == 0) = 0;

end

function [kx,ky,kz,k2,kmod] = make_kgrid(N, Lbox)
%MAKE_KGRID  FFT-compatible wavenumber grid.

if mod(N,2) == 0
    kk = [0:(N/2) (-N/2+1):-1];
else
    kk = [0:((N-1)/2) (-(N-1)/2):-1];
end

k1 = (2*pi/Lbox) * kk;
[kx,ky,kz] = ndgrid(k1,k1,k1);
k2 = kx.^2 + ky.^2 + kz.^2;
kmod = sqrt(k2);

end

function val = cic_interp_grid(field, x, y, z, Lbox)
%CIC_INTERP_GRID  Periodic CIC interpolation from a grid to particle positions.

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

function E = E_of_a(a, params)
%E_OF_A  Dimensionless Hubble parameter H(a)/H0 for flat Lambda-CDM.
E = sqrt(params.Omega_m./a.^3 + params.Omega_L);
end
