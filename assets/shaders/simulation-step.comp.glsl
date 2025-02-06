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
uniform float smoothingRadius;
uniform float tankLength;
uniform float tankWidth;
uniform float tankHeight;
uniform float time;

const float pi = 3.1415926535;
const float gravity = 9.81;
const float gas = 8.31;

vec3 random_dir() {
  return vec3(
    fract(sin(dot(gl_GlobalInvocationID.xy + time, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.yz + time, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.zx + time, vec2(12.9898, 78.233))) * 43758.5453)
  );
}

float poly6(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius * smoothingRadius - distance * distance);
  return 315.0 * b * b * b / (64.0 * pi * pow(smoothingRadius, 9));
}

vec3 grad_spiky(vec3 origin, vec3 position) {
  vec3 dir = origin != position ? normalize(origin - position) : normalize(random_dir());
  float b = max(0.0, smoothingRadius - distance(origin, position));
  return -45.0 / pi / pow(smoothingRadius, 6) * b * b * dir; // no minus here?
}

// vec3 lap_vis(vec3 origin, vec3 position) {

// }

float pressure(float density) {
  float restDensity = 0.5;
  float pressure = gas * (density - restDensity);
  return pressure;
}

vec3 acceleration(uint i) {
  vec3 position_i =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]);
  vec3 velocity_i =
    vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]);

  vec3 acceleration = vec3(0.0);

  for (uint j = 0; j < nParticles; j++) {
    if (j == i) continue;

    vec3 position_j =
      vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2]);
    vec3 velocity_j =
      vec3(particles[j].velocity[0], particles[j].velocity[1], particles[j].velocity[2]);

    /** acceleration due to pressure */
    acceleration -= particles[j].volume *
                    (pressure(particles[i].density) + pressure(particles[j].density)) /
                    (2.0 * particles[i].density) * grad_spiky(position_i, position_j);

    /** acceleration due to viscosity */
    // acceleration -= particles[j].volume * (velocity_j - velocity_i) / particles[i].density *
    //                 lap_vis(position_i, position_j);
  }

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

  velocity.x *= position.x < -tankLength || position.x > tankLength ? -0.5 : 1.0;
  position.x = clamp(position.x, -tankLength, tankLength);
  velocity.y *= position.y < -tankHeight || position.y > tankHeight ? -0.5 : 1.0;
  position.y = clamp(position.y, -tankHeight, tankHeight);
  velocity.z *= position.z < -tankWidth || position.z > tankWidth ? -0.5 : 1.0;
  position.z = clamp(position.z, -tankWidth, tankWidth);

  particles[i].position[0] = position.x;
  particles[i].position[1] = position.y;
  particles[i].position[2] = position.z;
  particles[i].velocity[0] = velocity.x;
  particles[i].velocity[1] = velocity.y;
  particles[i].velocity[2] = velocity.z;
}
