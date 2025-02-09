#include "Texture.hpp"

#include <iostream>
#include <stdexcept>
#include <string>

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

// TODO: delete copy functionality

// texture unit {
//   GL_TEXTURE_2D
//   GL_TEXTURE_3D
//   ...
// }
Texture::Texture(const std::string &texturePath) {
  glGenTextures(1, &textureId);
  glBindTexture(GL_TEXTURE_2D, textureId);

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  int width, height, nrChannels;
  unsigned char *texture = stbi_load(texturePath.c_str(), &width, &height, &nrChannels, 0);
  if (!texture) {
    std::cout << "ERROR TEXTURE" << std::endl;
    throw std::runtime_error("ERROR::TEXTURE::");
  }

  GLenum format;
  switch (nrChannels) {
    case 1:
      format = GL_RED;
      break;
    case 3:
      format = GL_RGB;
      break;
    case 4:
      format = GL_RGBA;
      break;
    default:
      break;
  }

  glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, GL_UNSIGNED_BYTE, texture);
  glGenerateMipmap(GL_TEXTURE_2D);

  glBindTexture(GL_TEXTURE_2D, 0);

  stbi_image_free(texture);
  glBindTexture(GL_TEXTURE_2D, textureId);
}

Texture::~Texture() {
  // glDeleteTextures(1, &textureId);
}

void Texture::use(GLenum textureUnit) {
  glActiveTexture(textureUnit);
  glBindTexture(GL_TEXTURE_2D, textureId);
}
