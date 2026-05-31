MATLAB Cosmic Web Toy Model
===========================

Run:
1. Put all six .m files in one folder.
2. In MATLAB, cd into that folder.
3. Run:
   main_cosmic_web

No pip, conda, external MATLAB toolbox, or external package is required.

This is a pedagogical Lambda-CDM + Particle-Mesh simulation:
- Gaussian random initial density field
- Zel'dovich-like initial displacement
- FFT Particle-Mesh gravity
- periodic comoving box
- simplified halo peak finder
- toy HOD galaxy assignment
- tidal-tensor cosmic-web classification

Important:
This is not a precision research simulator. It does not model baryonic gas
cooling, star formation, black hole feedback, radiation transfer, neutrinos,
or 2LPT initial conditions.
