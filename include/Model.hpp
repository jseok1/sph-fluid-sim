#pragma once

#include <assimp/cimport.h>
#include <assimp/postprocess.h>
#include <assimp/scene.h>
#include <assimp/types.h>

#include <glm/glm.hpp>
#include <string>
#include <vector>

#include "Mesh.hpp"
#include "glad/glad.h"

enum class NormalType {
  __FACE_NORMAL,
  __VERT_NORMAL
};

class Model {
 public:
  std::vector<Mesh> meshes;

  Model(const std::string &path, NormalType normalType) {
    aiPostProcessSteps normalFlag;
    switch (normalType) {
      case NormalType::__VERT_NORMAL: {
        normalFlag = aiProcess_GenSmoothNormals;
        break;
      }
      case NormalType::__FACE_NORMAL: {
        normalFlag = aiProcess_GenNormals;
        break;
      }
      default:
        break;
    }

    const aiScene *scene = aiImportFile(
      path.c_str(),
      aiProcess_Triangulate | normalFlag | aiProcess_JoinIdenticalVertices | aiProcess_FlipUVs
    );

    if (!scene || scene->mFlags & AI_SCENE_FLAGS_INCOMPLETE) {
      throw std::runtime_error("ERROR::ASSIMP::NULL SCENE");
    }

    load(scene, scene->mRootNode);
  }

  void draw() {
    for (auto &mesh : meshes) {
      mesh.draw();
    }
  }

  void draw(int nInstances) {
    for (auto &mesh : meshes) {
      mesh.draw(nInstances);
    }
  }

 private:
  void load(const aiScene *scene, aiNode *node) {
    for (int i = 0; i < node->mNumMeshes; i++) {
      aiMesh *mesh = scene->mMeshes[node->mMeshes[i]];

      std::vector<Vertex> vertices;
      std::vector<unsigned int> indices;

      for (int i = 0; i < mesh->mNumVertices; i++) {
        Vertex vert{};

        // positions
        vert.position.x = mesh->mVertices[i].x;
        vert.position.y = mesh->mVertices[i].y;
        vert.position.z = mesh->mVertices[i].z;

        // normals
        vert.normal.x = mesh->mNormals[i].x;
        vert.normal.y = mesh->mNormals[i].y;
        vert.normal.z = mesh->mNormals[i].z;

        vertices.push_back(vert);
      }

      for (int i = 0; i < mesh->mNumFaces; i++) {
        for (int j = 0; j < mesh->mFaces[i].mNumIndices; j++) {
          unsigned int index = mesh->mFaces[i].mIndices[j];

          indices.push_back(index);
        }
      }

      // TODO: should be passed in without creating copy otherwise that calls the destructor
      meshes.push_back(Mesh(vertices, indices));
    }

    for (int i = 0; i < node->mNumChildren; i++) {
      load(scene, node->mChildren[i]);
    }
  }
};
