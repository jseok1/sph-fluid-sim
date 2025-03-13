#version 460 core

struct Light {
  vec3 origin;
  vec3 color;
};

in vec2 fTexCoords;
in vec3 fPosition;
in vec3 fNormal;
in vec4 fHash;

out vec4 color;

uniform sampler2D gradient;

void main() {
  Light light;
  light.origin = vec3(10.0, 10.0, 10.0);
  light.color = vec3(1.0, 1.0, 1.0);

  vec3 lightDir = normalize(light.origin - fPosition);

  // vec3 fColor = vec3(texture(gradient, fTexCoords)); // 1D eventually?
  vec4 fColor = fHash;

  // vec3 ambient = light.color * fColor * 0.5;
  // vec3 diffuse = light.color * fColor * max(dot(normalize(fNormal), lightDir), 0.0);

  // color = vec4(ambient + diffuse, 1.0);
  color = fColor;
}
