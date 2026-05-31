function params = cosmology_params()
%COSMOLOGY_PARAMS  Return numerical and cosmological parameters.
%
% This file intentionally uses only base MATLAB features.
% The code is a pedagogical Lambda-CDM + Particle-Mesh toy model, not a
% precision replacement for CAMB/CLASS/GADGET/AREPO.
%
% Units:
%   length: comoving Mpc/h
%   mass:   Msun/h, only for approximate halo labels
%   time:   dimensionless scale-factor stepping

params = struct();

% ---- Cosmology: Planck-like flat Lambda-CDM ----
params.Omega_m = 0.315;
params.Omega_L = 0.685;
params.Omega_b = 0.049;
params.h       = 0.674;
params.H0      = 100.0 * params.h;       % km/s/Mpc, for reference labels
params.sigma8  = 0.811;
params.ns      = 0.965;

% ---- Simulation box ----
params.Ngrid = 256;        % PM mesh size. Try 128 after the 64^3 version runs.
params.Np1D  = 128;        % particles per side. 48^3 = 110592 particles.
params.Lbox  = 300.0;     % comoving Mpc/h
params.zi    = 49.0;      % start redshift. Increase to 99 for a stricter run.
params.ai    = 1.0/(1.0 + params.zi);
params.af    = 1.5;
params.Nstep = 350;

% ---- Numerical tuning for a visually clear teaching simulation ----
% These values are deliberately conservative. If the final web is too weak,
% increase force_boost to 1.5 or initial_displacement_cells to 0.35.
params.initial_displacement_cells = 0.28;   % RMS initial displacement in cell units
params.initial_delta_rms          = 0.05;   % RMS initial density contrast
params.force_boost                = 1.10;   % visual/time-unit normalization
params.random_seed                = 7 ;%'shuffle';    % random initial disturbance

% ---- Output ----
params.output_dir = 'snapshots';
params.save_every = 12;       % save a PNG every this many steps
params.plot_every = 6;        % refresh figure every this many steps
params.sample_particles_for_plot = 12000;

% ---- Halo and galaxy toy model ----
params.max_halos              = 250;
params.halo_threshold_sigma   = 2.6;
params.halo_min_separation    = 4;     % grid cells
params.halo_radius_cells      = 3;     % mass aperture radius
params.Mmin_galaxy            = 3.0e12; % Msun/h, approximate
params.M1_satellite           = 8.0e13; % Msun/h, approximate
params.hod_alpha              = 0.85;
params.max_galaxies_per_halo  = 25;

% ---- Cosmic-web classification ----
params.web_smooth_sigma_cells = 1.6;
params.web_lambda_threshold   = 0.10;

end
