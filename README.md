# SPH Fluid Simulation (WIP)

[demo](https://github.com/jseok1/sph-fluid-sim/README.mp4)

A particle-based Lagrangian approach to fluid simulation using *smoothed particle hydrodynamics* (SPH).


🚧 Currently a work-in-progress. 🚧


<!-- Smoothed-Particle Hydrodynamics (SPH)

Particle-based Lagrangian approach (as opposed to grid-based Eulerian)

SPH is an interpolation method for particle systems. With SPH, field quantities that are only defined at discrete particle locations can be evaluated anywhere in space.

Local radial smoothing kernels with finite support.
Should be normalized such that area under kernel is 1.

Conservation of mass. <- guaranteed in particle-based simulations
Conservation of momemtum (Navier-Stokes).




https://matthias-research.github.io/pages/publications/sca03.pdf
https://sph-tutorial.physics-simulation.org/pdf/SPH_Tutorial.pdf

screen space shader?

Gotcha:
In std430, vec3's are padded to be vec4's.

SPH
Navier-Stokes
Look ahead particle position trick.
Fix boundary deficiency.
Surface tension.
fixed-radius near neighbor problem
sparse grid storage.

https://ramakarl.com/pdfs/2014_Hoetzlein_FastFixedRadius_Neighbors.pdf

uniform grid -> using index sort (optimize further using Z-curves - also important on GPU?) (handles with insertion sort)
-> (better memory) using spatial hashing (very simple)

SESPH - 
PCISPH - predicted position and velocity

gridCounters
gridCells
parallel radix sort?

https://arxiv.org/abs/2212.07679



index sort + spatial hashing for infinite domains + radix sort


Comparison of parallel GPU sorting algorithms:
https://arxiv.org/pdf/1511.03404

bitonic (multistep + adaptive), merge, quick, radix, sample

radix is one of the fastest for short keys (which in this case will be bounded for )
64 or 32 bit keys

Z-index sort uses insertion sort

maybe try radix, merge, and bitonic
Could even terminate radix sort early based on mHash number of bits?

parallel radix sort
https://gpuopen.com/download/publications/Introduction_to_GPU_Radix_Sort.pdf
https://www.sci.utah.edu/~csilva/papers/cgf.pdf

The block size is determined
as a multiplier of the SIMD size to exploit the full power of
SIMD processing unit

Blelloch:
https://ams148-spring18-01.courses.soe.ucsc.edu/system/files/attachments/note5.pdf -->
