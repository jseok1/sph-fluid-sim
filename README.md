# SPH Fluid Simulation

<!-- https://github.com/user-attachments/assets/a33e29b2-1dcb-4b89-b545-714844991433 -->

https://github.com/user-attachments/assets/61a6bb0c-f2a6-4dd4-bd9d-c5dfddc946a7

## Introduction

This is a real-time, GPU-accelerated Lagrangian fluid simulator based on smoothed particle hydrodynamics (SPH).

## Smoothed Particle Hydrodynamics

Smoothed Particle Hydrodynamics (SPH) is a fully Lagrangian, particle-based method for simulating fluids. Instead of discretizing continuous fields on a grid like Eulerian approaches, fields are discretized using particles that carry state (position, velocity, density, pressure). These continuous fields are then approximated from neighboring particles using a radially symmetric smoothing kernel with some finite support radius $h$, denoted $W(r, h)$.

```math
\begin{equation}
A(\mathbf{x}) \approx \sum_jA_j\frac{m_j}{\rho_j}W(\|\mathbf{x} - \mathbf{x}_j\|, h)
\end{equation}
```

$A$ is the field of interest. $\nabla A$ can be evaluated similarly. Conveniently, derivatives only affect the smoothing kernel.

```math
\nabla A(\mathbf{x}) = \sum_j A_j\frac{m_j}{\rho_j}\nabla W(\|\mathbf{x} - \mathbf{x}_j\|, h)
```

## Navier-Stokes Equations

The Navier-Stokes equations describe how fluid momentum changes over time. They express conservation of mass and conservation of momentum.

### Conservation of Mass
```math
\begin{equation}
\frac{\partial \rho}{\partial t} + \nabla \cdot (\rho\mathbf{v}) = 0
\end{equation}
```

For incompressible fluids like water, density is constant, meaning $\frac{\partial\rho}{\partial t} = 0$. The conservation of mass equation then simplifies to the following.

<!-- I should explain this in terms of flux. The second term is how much density is being carried by the velocity field spatially. The divergence of this field describes how much density change is incoming/outgoing at every point. -->

```math
\begin{equation}
\nabla \cdot \textbf{v} = 0
\end{equation}
```

The velocity field must be divergence free.

### Conservation of Momentum

```math
\begin{equation}
\frac{D\textbf{v}}{Dt} = \frac{\partial\mathbf{v}}{\partial t} + (\mathbf{v} \cdot \nabla)\mathbf{v} = -\frac{1}{\rho}\nabla p + \nu\nabla^2\textbf{v} + \frac{\textbf{g}}{\rho}
\end{equation}
```

$\frac{D\textbf{v}}{Dt}$ denotes the material derivative of velocity. In the Eulerian point of view, we would be concerned with evaluating $\frac{\partial \mathbf{v}}{\partial t}$, i.e. the change in velocity over time at a fixed position. In our Lagrangian point of view however, we are concerned with evaluating $\frac{D\textbf{v}}{Dt}$, i.e. the change in velocity over time at a variable position (as advected by the velocity field).

<!-- Note the second term is velocity flux. -->

Under the semi-implicit Euler method, the Navier-Stokes equations gives a way to time integrate the positions of particles. The time step may be chosen using the Courant-Friedrichs-Lewy (CFL) condition.

<!-- TODO: Verlet integration -->

The density, pressure, and kinematic viscosity terms can be approximated at each particle position via the SPH formulation.

```math
\begin{equation}
\rho_i = \sum_j m_j \frac{\rho_j}{\rho_j}W(\|\mathbf{x}_i - \mathbf{x}_j\|, h) = \sum_j m_j W(\|\mathbf{x}_i - \mathbf{x}_j\|, h)
\end{equation}
```

```math
\begin{equation}
-\nabla p_i = -\sum_j m_j \frac{p_j}{\rho_j}\nabla W(\|\mathbf{x}_i - \mathbf{x}_j\|, h) \approx -\sum_j m_j \frac{p_i + p_j}{2\rho_j}\nabla W(\|\mathbf{x}_i - \mathbf{x}_j\|, h)
\end{equation}
```

```math
\begin{equation}
-\nu\nabla^2 \mathbf{v}_i = \nu\sum_j m_j \frac{\mathbf{v}_j}{\rho_j}\nabla^2 W(\|\mathbf{x}_i - \mathbf{x}_j\|, h) \approx \nu\sum_j m_j \frac{\mathbf{v}_j - \mathbf{v}_i}{\rho_j}\nabla^2 W(\|\mathbf{x}_i - \mathbf{x}_j\|, h)
\end{equation}
```

The pressure and viscosity terms do not exactly follow the SPH forumulation, as they must be symmetrized.

<!-- TODO: kernels, neighborhood search, time integration and CFL condition, PBF, boundaries and free surface. -->

## Usage

This project relies on OpenGL 4.6, the Conan C/C++ package manager, and CMake build system. To install dependencies and build from the root directory, create a [Conan profile](https://docs.conan.io/2/reference/config_files/profiles.html) and run the following commands.

On Windows:

```bash
conan install . --build=missing --profile=release
cmake --preset conan-default
cmake --build --preset conan-release
./build/Release/sph-fluid-sim.exe
```

On Linux/MacOS:

```bash
conan install . --build=missing --profile=release
cmake --preset conan-release
cmake --build --preset conan-release
./build/Release/sph-fluid-sim
```

Use `W`, `A`, `S`, `D`, `Space`, and `Shift` to move around. Use `P` to play/pause the simulation.

## References
Matthias Müller, David Charypar, and Markus Gross. 2003. Particle-Based Fluid
Simulation for Interactive Applications. _Fluid Dynamics_ 2003, 154–159.

Nadathur Satish, Mark Harris, and Michael Garland. 2009. Designing efficient
sorting algorithms for manycore GPUs. In _2009 IEEE International Symposium on
Parallel Distributed Processing_. 1–10. https://doi.org/10.1109/IPDPS.2009.5161005

Markus Ihmsen, Nadir Akinci, Markus Becker, and Matthias Teschner. 2011. A
Parallel SPH Implementation on Multi-Core CPUs. _Computer Graphics Forum_ 30,
1 (2011), 99–112. https://doi.org/10.1111/j.1467-8659.2010.01832.x

Markus Ihmsen, Jens Orthmann, Barbara Solenthaler, Andreas Kolb, and Matthias
Teschner. 2014. SPH Fluids in Computer Graphics. In _Eurographics 2014 - State of
the Art Reports_, Sylvain Lefebvre and Michela Spagnuolo (Eds.). The Eurographics
Association. https://doi.org//10.2312/egst.20141034

Dan Koschier, Jan Bender, Barbara Solenthaler, and Matthias Teschner. 2019.
Smoothed Particle Hydrodynamics Techniques for the Physics Based Simulation
of Fluids and Solids. _Eurographics 2019 - Tutorials_ (2019). https://doi.org/10.2312/
EGT.20191035

Miles Macklin and Matthias Müller. 2013. Position based fluids. _ACM Trans. Graph._
32, 4, Article 104 (July 2013), 12 pages. https://doi.org/10.1145/2461912.2461984

<!-- Density Constraint:
```math
C_i(\mathbf{p}_1, \dots, \mathbf{p}_n) = \frac{\rho_i}{\rho_0} - 1
``` -->



<!-- Smoothed-Particle Hydrodynamics (SPH)

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
as a lambda of the SIMD size to exploit the full power of
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



