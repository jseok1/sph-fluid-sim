#pragma once

#include <glm/glm.hpp>
#include <vector>

struct Particle {
  float mass;
  float density;
  float volume;
  float pressure;
  float position[3];
  float velocity[3];
};

struct ParticleHandle {
  unsigned int hash;
  unsigned int offset;
};

class Fluid {
 public:
  std::vector<Particle> particles;

  Fluid(int num_x, int num_y, int num_z) {
    for (int i = 0; i < num_x; i++) {
      for (int j = 0; j < num_y; j++) {
        for (int k = 0; k < num_z; k++) {
          Particle particle;
          particle.mass = 0.001f;
          particle.density = 0.0f;
          particle.volume = 0.0f;
          particle.pressure = 0.0f;
          particle.position[0] = static_cast<float>(i) / num_x * 2.5f - 1.25f; // spacing should depend on smoothing radius
          particle.position[1] = static_cast<float>(j) / num_y * 1.5f - 0.75f;
          particle.position[2] = static_cast<float>(k) / num_z * 1.5f - 0.75f;
          particle.velocity[0] = 0.0f;
          particle.velocity[1] = 0.0f;
          particle.velocity[2] = 0.0f;

          particles.push_back(particle);
        }
      }
    }
  }
};
