#pragma once

#include <glad/glad.h>

#include <string>
#include <unordered_map>

class Texture {
 public:
  Texture(const std::string& texturePath);
  ~Texture();

  void use(GLenum textureUnit);

 private:
  GLuint textureId;
};

/**
 * System
 *   TextureSubsystem
 *     * load(path)
 *   ShaderSubsystem
 *     * load(path)
 *   MeshSubsystem
 *     * list of meshes, each with possibly multiple textures
 *     * load(path)
 *   Renderer
 *   Scene
 *     Camera
 *     Models --> index into meshes
 *
 *
 * Shader <-> VAO <-> [VBO, VBO, VBO]
 * APIwise, one giant renderer class makes the most sense
 *
 * Rendering pipeline is run when calling glDrawArrays or glDrawElements
 *
 * Global singletons seems to be actually a common pattern.
 * The idea is you're kind of creating an abstraction API over OpenGL but separating that API
 * into different subsystem classes.
 * This actually needs to be the approach otherwise how do you consolidate multiple models into the
 * same VBO for example?
 *
 * Scene class
 *   Should I store the Mesh hierarchy as a tree?
 * Renderable --> renders itself (can be triangle_strip, etc.) <--> associated with some Material
 *
 * Things should be batched. (maybe everything can go into the same VBO, VAO for now?)
 *
 * Subengines manage OpenGL calls and operate on data structs. Idea is to decouple OpenGL with data.
 * The problem is that OpenGL is based on global state setting, so it should be managed by a global
 * system.
 *
 * Mesh -> texture IDs
 */
