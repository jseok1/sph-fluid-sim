# SPH Fluid Simulation (WIP)

<!-- https://github.com/user-attachments/assets/a33e29b2-1dcb-4b89-b545-714844991433 -->

https://github.com/user-attachments/assets/61a6bb0c-f2a6-4dd4-bd9d-c5dfddc946a7


A real-time Lagrangian fluid simulator based on smoothed particle hydrodynamics (SPH).

Solves the incompressible Navier-Stokes equations using a semi-implicit Euler scheme.
```math
\frac{D\textbf{v}}{Dt} = -\frac{1}{\rho}\nabla p + \nu\nabla^2\textbf{v} + \frac{\textbf{g}}{\rho}
```

```math
\nabla \cdot \textbf{v} = 0
```



<!-- 🚧 Currently a work-in-progress. 🚧 -->


<!-- Smoothed-Particle Hydrodynamics (SPH)

Particle-based Lagrangian approach (as opposed to grid-based Eulerian)

SPH is an interpolation method for particle systems. With SPH, field quantities that are only defined at discrete particle locations can be evaluated anywhere in space.

Local radial smoothing kernels with finite support.
Should be normalized such that area under kernel is 1.

Conservation of mass. <- guaranteed in particle-based simulations
Conservation of momemtum (Navier-Stokes).


TODO: radix sort key size is bounded by the hashtable size in spatial hashing, so you don't need 4 passes of 8 bits for a uint technically. Speed up.


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

https://ephyslab.uvigo.es/publica/documents/file_259Dominguez_etal_2010_IJNMF_DOI.pdf
"sliding vector, static matrix, linked list"
CLL vs. Verlet (does CLL mean uniform grid?)

Cell lists are a spatial grid (3D or 2D) that divides space into cells (small cubes/boxes).
Verlet lists are neighbor lists for each particle.

In SPH, cell lists are the standard, while in molecular dynamics, Verlet lists are the standard.
Verlet lists take O(N^2) time to construct.

DualSPHysics uses CLL. With CLL, an actual list of neighbors is NOT generated.


CLL using compressed neighbor lists. (Most direct competitor is compact hashing)
Compute cell indices using Morton Codes (bit interleaving).
Build a compact list -> (cell index [Morton Code], index of first particle in this cell)
With this approach, you can query the number of particles in a cell by taking the differenec between
the start indices of adjacent compact lists.
particle -> marker if different from previous particle -> prefix sum
-> if marker is 1, write (particle index, cell index) to compact cell array.

Based on the z-order, compute a list of sub-ranges of cells that cover the 3x3x3 neighborhood.
The min and max cell indices are computed by the BigMin-LitMax algorithm. These indices are then
found in the compact list via ternery search with fallback to linear search.
The idea with this algorithm is to compute a compressed neighborhood list for each particle ONCE per
iteration.

Use a SoA!!!!!!!! Best to combine into vec4s (mass + position), (velocity, density)
Storing start AND END index is useful for avoiding loops in the neighborhood query. Could also just
sort particules themselves, not their handles.
GPUSHP uses a fixed-sized neighbor list with a sentinal value ("neighbor-major").
https://arxiv.org/pdf/2207.11328

(This talk about the NVIDIA GPU neighbor search. Basically what I have but cross-reference this just in case.)
https://wickedengine.net/2018/05/scalabe-gpu-fluid-simulation/

int3 cellIndex = floor(particleA.position / h);

for(int i = -1; i <= 1; ++i)
{
  for(int j = -1; j <= 1; ++j)
  {
    for(int k = -1; k <= 1; ++k)
    {
       int3 neighborIndex = cellIndex + int3(i, j, k);
       uint flatNeighborIndex = GetFlatCellIndex(neighborIndex);
       
       // look up the offset to the cell:
       uint neighborIterator = cellOffsetBuffer[flatNeighborIndex];

       // iterate through particles in the neighbour cell (if iterator offset is valid)
       while(neighborIterator != 0xFFFFFFFF && neighborIterator < particleCount)
       {
         uint particleIndexB = particleIndexBuffer[neighborIterator];
         if(cellIndexBuffer[particleIndexB] != flatNeighborIndex)
         {
           break;  // it means we stepped out of the neighbour cell list!
         }

         // Here you can load particleB and do the SPH evaluation logic

         neighborIterator++;  // iterate...
       }

    }
  }
}

(Don't do the triple loop or unroll though. Keep using the lookup table.)


Amortize the cost of neighbor search by building a neighbor list per particle. Precompute the maximum
number of neighbors.

cellStart[] is like head[] array for linked list.
cellIDtoParticleID[]

Things to try:
1. Use Morton codes for spatial ordering instead of hashing. See if this improves performance.
   While also sorting particles array every few simulation steps.
2. Use a SoA format.
3. See if you can utilize shared memory in more places besides radix sort.
4. Each thread should handle 4-8 particles.
5. See if the neighbor loop can be improved.
6. [FINITE GRID]

IF HASH IS STORED SEPERATELY, WILL THE (HASH) KERNEL RUNTIME BE LESS AND PHYSICS KERNEL RUNTIME BE MORE?


Are Morton codes a form of hashing? Hilbert codes are another alternative.

Z-index sort is useful for reordering particles themselves or in a finite domain.


SoA should help because more writes can be coalesced together?




SESPH
for each particle i do
    compute density
    compute pressure
for each particle i do
    compute forces
    integrate


PCISPH (can use larger time steps, resulting in greater overall efficiency)
for each particle i do
    compute forces
    pressure = 0
    pressure_force = vec3(0,0,0)
k = 0
while (max() > eta or k < 3) do
    for each particle i do
        predict velocity
        predict position
    for each particle i do
        update distance to neighbors
        predict density variation
        update pressure
    for each particle i do
        compute pressure force
    k++
for each particle i do
    integrate

IISPH


DFSPH



https://arxiv.org/abs/2212.07679



index sort + spatial hashing for infinite domains + radix sort


Comparison of parallel GPU sorting algorithms:
https://arxiv.org/pdf/1511.03404

bitonic (multistep + adaptive), merge, quick, radix, sample

radix is one of the fastest for short keys (which in this case will be bounded for )
64 or 32 bit keys

Z-index sort uses insertion sort

maybe try radix, merge, and bitonic
Could even terminate radix sort early based on HASH_TABLE_SIZE number of bits?

parallel radix sort
https://gpuopen.com/download/publications/Introduction_to_GPU_Radix_Sort.pdf
https://www.sci.utah.edu/~csilva/papers/cgf.pdf

The block size is determined
as a multiplier of the SIMD size to exploit the full power of
SIMD processing unit

Blelloch:
https://ams148-spring18-01.courses.soe.ucsc.edu/system/files/attachments/note5.pdf -->

<!-- ## Incompressible Fluid Solvers -->
<!---->
<!-- ```math -->
<!-- \frac{D\textbf{v}}{Dt} = -\frac{1}{\rho}\nabla p + \nu\nabla^2\textbf{v} + \frac{\textbf{g}}{\rho} -->
<!-- \nabla \cdot \textbf{v} = 0 -->
<!-- ``` -->
<!---->
<!---->
<!-- CLF condition. -->
<!---->
<!-- PCISPH < IISPH < DFSPH -->
<!---->
<!-- ## Neighborhood Search -->
<!---->
<!-- Sort particles based on uniform grid and Z-index sorting. -->
<!---->
<!---->
<!-- ### GPU Radix Sort -->
<!---->
<!-- ### Spatial Hashing with a Z-Order Curve -->
<!---->
<!---->
<!-- ## Rigid-Fluid Boundary Handling -->
<!---->
<!-- * Particle-based boundary handling is popular. Surface-sampled approaches (as opposed to -->
<!-- volume-sampled) approaches is more popular. -->
<!---->
<!---->
<!-- How do you evaluate pressure values at boundaries? -->
<!-- pressure mirroring: assume the pressure at a boundary particle is the same as that of the fluid -->
<!-- particle being evaluated. -->
<!-- pressure boundaries: use SPH-like formulation to estimate pressure values at boundary particles -->
<!-- using a discretization of the pressure Poisson equation, resulting in a system of equations that is solved using a relaxed Jacobi method. -->
<!-- moving least squares pressure extrapolation -->
<!---->
<!---->
<!---->
<!-- ALSO: -->
<!-- Which kernels? -->
<!-- cubic spline -->
<!---->
<!-- Surface tension. -->


