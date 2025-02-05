Smoothed-Particle Hydrodynamics (SPH)

Particle-based Lagrangian approach (as opposed to grid-based Eulerian)

SPH is an interpolation method for particle systems. With SPH, field quantities that are only defined at discrete particle locations can be evaluated anywhere in space.

Local radial smoothing kernels with finite support.
Should be normalized such that area under kernel is 1.

Conservation of mass. <-- guaranteed in particle-based simulations
Conservation of momemtum (Navier-Stokes).




https://matthias-research.github.io/pages/publications/sca03.pdf
https://sph-tutorial.physics-simulation.org/pdf/SPH_Tutorial.pdf

screen space shader?

Gotcha:
In std430, vec3's are padded to be vec4's.
