% MAIN_COSMIC_WEB
% Pedagogical MATLAB simulation of Lambda-CDM expansion and cosmic-web growth.
%
% Run this file after placing all six .m files in the same folder:
%   main_cosmic_web.m
%   cosmology_params.m
%   make_initial_conditions.m
%   particle_mesh_step.m
%   find_halos_and_galaxies.m
%   visualize_cosmic_web.m
%
% This is not a precision cosmological simulation. It is a compact teaching
% model using Gaussian initial perturbations, Zel'dovich-like displacements,
% Particle-Mesh gravity, a toy halo finder, and a toy galaxy occupation model.

clear; clc; close all;

params = cosmology_params();

if ~exist(params.output_dir, 'dir')
    mkdir(params.output_dir);
end

fprintf('=== MATLAB Cosmic Web Toy Model ===\n');
fprintf('Box: %.1f Mpc/h, PM grid: %d^3, particles: %d^3\n', ...
    params.Lbox, params.Ngrid, params.Np1D);
fprintf('Start z = %.1f, end z = 0, steps = %d\n', params.zi, params.Nstep);
fprintf('No external packages or toolboxes are required by design.\n\n');

% ---- Initial conditions ----
fprintf('Generating initial conditions...\n');
[x,y,z,px,py,pz,delta0] = make_initial_conditions(params);

rho = [];
delta = delta0;

% ---- Initial diagnostic figure ----
figure('Color','w','Name','Initial density perturbation');
mid = round(params.Ngrid/2);
imagesc(log10(1 + max(delta0(:,:,mid), -0.95)));
axis image; set(gca,'YDir','normal'); colorbar;
title(sprintf('Initial density perturbation, z = %.1f', params.zi));
xlabel('grid cell'); ylabel('grid cell');
drawnow;

% ---- Time integration in scale factor ----
avec = linspace(params.ai, params.af, params.Nstep);
tStart = tic;

for n = 1:(params.Nstep-1)
    a  = avec(n);
    da = avec(n+1) - avec(n);

    [x,y,z,px,py,pz,rho,delta] = particle_mesh_step(x,y,z,px,py,pz,a,da,params);

    zred = 1/a - 1;

    if mod(n, params.plot_every) == 0 || n == 1
        plot_live_state(delta, x, y, z, a, n, params);
    end

    if mod(n, params.save_every) == 0 || n == 1
        fname = fullfile(params.output_dir, sprintf('density_step_%04d_z_%06.2f.png', n, zred));
        saveas(gcf, fname);
    end

    if mod(n, 20) == 0 || n == params.Nstep-1
        fprintf('Step %4d/%4d | a = %.4f | z = %.2f | elapsed %.1f s\n', ...
            n, params.Nstep-1, a, zred, toc(tStart));
    end
end

% ---- Final analysis ----
fprintf('\nFinding halo candidates and assigning toy galaxies...\n');
[halos, galaxies] = find_halos_and_galaxies(rho, params);

fprintf('Classifying and visualizing cosmic web...\n');
webtype = visualize_cosmic_web(rho, halos, galaxies, params, 1.0);

finalFig = fullfile(params.output_dir, 'final_cosmic_web_summary.png');
saveas(gcf, finalFig);

% ---- Save final data ----
outMat = fullfile(params.output_dir, 'final_state.mat');
save(outMat, 'x','y','z','px','py','pz','rho','delta','halos','galaxies','webtype','params','-v7.3');

fprintf('\nDone.\n');
fprintf('Saved final figure: %s\n', finalFig);
fprintf('Saved final data:   %s\n', outMat);

% ======================================================================

function plot_live_state(delta, x, y, z, a, step, params)
%PLOT_LIVE_STATE  Lightweight live visualization during integration.

N = size(delta,1);
mid = round(N/2);
Lbox = params.Lbox;
zred = 1/a - 1;

figure(10); clf;

subplot(1,2,1);
imagesc(log10(1 + max(delta(:,:,mid), -0.95)));
axis image; set(gca,'YDir','normal'); colorbar;
title(sprintf('Density slice | step %d | z = %.2f', step, zred));
xlabel('grid cell'); ylabel('grid cell');

subplot(1,2,2);
Np = numel(x);
Ns = min(params.sample_particles_for_plot, Np);
idx = round(linspace(1, Np, Ns));
scatter3(x(idx), y(idx), z(idx), 1, '.');
axis equal; xlim([0 Lbox]); ylim([0 Lbox]); zlim([0 Lbox]);
grid on;
xlabel('x Mpc/h'); ylabel('y Mpc/h'); zlabel('z Mpc/h');
title('Particle sample');

drawnow;

end
