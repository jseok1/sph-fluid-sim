#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in; // why 128?
layout(rgba32f, binding = 0) uniform image2D screen;

// maybe idea is every invocation uses ALL particles to update a single particle in the next time step
// but invocations can probably share?

// Uniform Buffers (UBOs) or Shader Storage Buffers (SSBOs)
// std140 -> UBOs (padding but predictable)
// std430 -> SSBOs (tighter packing)
// UBOs are read-only and have strict size limitations (64 KB)
// SSBOs are read-write and have significantly more storage capacity than UBOs (MBs)

// C++
// struct Particle {
//     glm::vec4 position; // xyz: position, w: lifetime
//     glm::vec4 velocity; // xyz: velocity, w: mass
// };

// need: mass, (position), (velocity), [density], [pressure]
//
// update everything else ===
// density -> mass, position (can be done in parellel)
// pressure -> density (can be done immediately)

// update position ===
// a_pressure (i) -> mass (j), pressure (i, j), density (j), position (i, j)
// a_viscosity (i) -> mass (j), velocity (i, j), density (j), position (i, j)
// g
//
// new position vs old position

layout(std430, binding = 0) buffer ParticleBuffer {
struct Particle {
vec4 position; // xyz: position, w: lifetime
vec4 velocity; // xyz: velocity, w: mass
}
particles[];
};

uniform float deltaTime;
uniform vec3 acceleration; // e.g., gravity

layout(local_size_x = 256) in; // Workgroup size

void main() {
uint i = gl_GlobalInvocationID.x;

    // Update velocity with acceleration
particles[i].velocity.xyz += acceleration * deltaTime;

    // Update position using velocity
particles[i].position.xyz += particles[i].velocity.xyz * deltaTime;

    // Reduce lifetime
particles[i].position.w -= deltaTime;

    // Reset particle if lifetime is over
if(particles[i].position.w < 0.0) {
particles[i].position.xyz = vec3(0.0); // Reset position
particles[i].velocity.xyz = vec3(0.0); // Reset velocity
particles[i].position.w = 5.0; // Reset lifetime
}
}

// read/write SSBO with uniform grid 
