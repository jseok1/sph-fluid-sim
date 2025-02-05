#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

struct Particle {
  float mass;
  float density;
  float volume;
  float position[3];
  float velocity[3];
};

layout(std430, binding = 0) buffer ParticleBuffer {
  Particle particles[];
};

uniform int nParticles;
uniform float smoothingRadius;

const float pi = 3.1415926535;

float poly6(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius * smoothingRadius - distance * distance);
  return 315.0 * b * b * b / (64.0 * pi * pow(smoothingRadius, 9));
}

float density(uint i) {
  float density = 0.0;
  for (uint j = 0; j < nParticles; j++) {
    if (j == i) continue; // correct?

    density += particles[j].mass *
               poly6(
                 vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]),
                 vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2])
               );
  }
  return density;
}

float volume(uint i) {
  return particles[i].mass / particles[i].density;
}

void main() {
  uint i = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y + gl_GlobalInvocationID.z;

  particles[i].density = density(i);
  particles[i].volume = volume(i);
}
