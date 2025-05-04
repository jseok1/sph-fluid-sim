#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) buffer Positions {
  float g_positions[];
};

layout(std430, binding = 7) buffer Velocities {
  float g_velocities[];
};

layout(std430, binding = 8) buffer Densities {
  float g_densities[];
};

layout(std430, binding = 9) buffer Pressures {
  float g_pressures[];
};

uniform uint nParticles;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  uint i = g_tid;

  float s = 2.0;  // side length of water cube (should depend on smoothing radius)
  float n = ceil(pow(nParticles, 1.0 / 3.0));
  
  float x = mod(i, n) * s / n - s / 2.0;
  float y = floor(mod(i, n * n) / n) * s / n - s / 2.0;
  float z = floor(i / (n * n)) * s / n - s / 2.0;

  vec3 position_i = vec3(x, y, z);
  vec3 velocity_i = vec3(0.0);

  float density_i = 0.0;
  float pressure_i = 0.0;

  g_positions[3 * i] = position_i.x;
  g_positions[3 * i + 1] = position_i.y;
  g_positions[3 * i + 2] = position_i.z;
  g_velocities[3 * i] = velocity_i.x;
  g_velocities[3 * i + 1] = velocity_i.y;
  g_velocities[3 * i + 2] = velocity_i.z;
  g_densities[i] = density_i;
  g_pressures[i] = pressure_i;
}

