#version 460 core

in vec3 aColor;

out vec4 FragColor;

void main() {
  FragColor = vec4(aColor, 1.0);
}
