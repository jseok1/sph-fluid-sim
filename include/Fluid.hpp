#pragma once

#include <glm/glm.hpp>
#include <vector>

struct Particle {
  float mass;
  float density;
  float volume;
  float position[3];
  float velocity[3];
};

class Fluid {
 public:
  std::vector<Particle> particles;

  Fluid(int num_x, int num_y, int num_z) {
    for (int i = 0; i < num_x; i++) {
      for (int j = 0; j < num_y; j++) {
        for (int k = 0; k < num_z; k++) {
          Particle particle;
          particle.mass = 0.1f;  // water has a density of 998 kg/m^3
          particle.density = 0.0f;
          particle.volume = 0.0f;
          particle.position[0] = static_cast<float>(i) / num_x * 5.0f - 2.5f;
          particle.position[1] = static_cast<float>(j) / num_y * 2.5f - 1.25f;
          particle.position[2] = static_cast<float>(k) / num_z * 2.5f - 1.25f;
          particle.velocity[0] = 0.0f;
          particle.velocity[1] = 0.0f;
          particle.velocity[2] = 0.0f;

          particles.push_back(particle);
        }
      }
    }
  }
};
