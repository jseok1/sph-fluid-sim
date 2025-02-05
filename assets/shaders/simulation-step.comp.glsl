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

uniform float deltaTime;
uniform int nParticles;
uniform float tankLength;
uniform float tankWidth;
uniform float tankHeight;

const float pi = 3.1415926535;
const float gravity = 9.81;
const float gas = 8.31;

float poly6(vec3 origin, float radius, vec3 position) {
  return 315.0 * pow(max(0.0, pow(radius, 2) - pow(length(origin - position), 2)), 3) /
         (64.0 * pi * pow(radius, 9));
}

vec3 grad_spiky(vec3 origin, float radius, vec3 position) {
  return -45.0 / pi / pow(radius, 6) * pow(max(0.0, radius - length(origin - position)), 2) *
         normalize(origin - position);
}

float pressure(float density) {
  float restDensity = 0.01;
  float pressure = gas * (density - restDensity);
  return pressure;
}

vec3 acceleration(uint i) {
  vec3 acceleration = vec3(0.0);

  /** acceleration due to pressure */
  for (uint j = 0; j < nParticles; j++) {
    vec3 delta =
      normalize(
        vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]) -
        vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2])
      ) *
      0.01;

    acceleration -=
      particles[j].volume * (pressure(particles[i].density) + pressure(particles[j].density)) /
      (2.0 * particles[i].density) *
      (poly6(
         vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]) + delta,
         10.0,
         vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2])
       ) -
       poly6(
         vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]) - delta,
         10.0,
         vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2])
       ));
    // grad_spiky(
    //   vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]),
    //   10.0,
    //   vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2])
    // );
  }

  /** acceleration due to viscosity */

  /** acceleration due to gravity */
  acceleration.y -= gravity;

  return acceleration;
}

void main() {
  uint i = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y + gl_GlobalInvocationID.z;

  vec3 position =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]);
  vec3 velocity =
    vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]);

  velocity += acceleration(i) * deltaTime;
  position += velocity * deltaTime;

  if (abs(position.x) > tankLength) {
    position.x = sign(position.x) * tankLength;
    velocity.x *= -0.5;
  }
  if (abs(position.y) > tankHeight) {
    position.y = sign(position.y) * tankHeight;
    velocity.y *= -0.5;
  }
  if (abs(position.z) > tankWidth) {
    position.z = sign(position.z) * tankWidth;
    velocity.z *= -0.5;
  }

  particles[i].position[0] = position.x;
  particles[i].position[1] = position.y;
  particles[i].position[2] = position.z;
  particles[i].velocity[0] = velocity.x;
  particles[i].velocity[1] = velocity.y;
  particles[i].velocity[2] = velocity.z;
}
