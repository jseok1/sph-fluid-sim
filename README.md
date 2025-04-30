# SPH Fluid Simulation (WIP)

https://github.com/user-attachments/assets/a33e29b2-1dcb-4b89-b545-714844991433

A particle-based Lagrangian approach to fluid simulation using *smoothed particle hydrodynamics* (SPH).


🚧 Currently a work-in-progress. 🚧


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

SESPH - 
PCISPH - predicted position and velocity

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
