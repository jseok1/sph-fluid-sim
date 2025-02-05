#pragma once

#include <assimp/cimport.h>
#include <assimp/postprocess.h>
#include <assimp/scene.h>
#include <assimp/types.h>

#include <glm/glm.hpp>
#include <string>
#include <vector>

#include "Mesh.hpp"
#include "Texture.hpp"
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

 private:
  void load(const aiScene *scene, aiNode *node) {
    for (int i = 0; i < node->mNumMeshes; i++) {
      aiMesh *mesh = scene->mMeshes[node->mMeshes[i]];

      std::vector<Vertex> vertices;
      std::vector<unsigned int> indices;
      std::vector<Texture> textures;

      for (int i = 0; i < mesh->mNumVertices; i++) {
        Vertex vert{};

        // positions
        vert.position.x = mesh->mVertices[i].x;
        vert.position.y = mesh->mVertices[i].y;
        vert.position.z = mesh->mVertices[i].z;

        // normals
        if (mesh->mNormals) {
          vert.normal.x = mesh->mNormals[i].x;
          vert.normal.y = mesh->mNormals[i].y;
          vert.normal.z = mesh->mNormals[i].z;
        }

        // texture coordinates
        if (mesh->mTextureCoords[0]) {
          vert.textureCoords.x = mesh->mTextureCoords[0][i].x;
          vert.textureCoords.y = mesh->mTextureCoords[0][i].y;
        }

        vertices.push_back(vert);
      }

      for (int i = 0; i < mesh->mNumFaces; i++) {
        for (int j = 0; j < mesh->mFaces[i].mNumIndices; j++) {
          unsigned int index = mesh->mFaces[i].mIndices[j];

          indices.push_back(index);
        }
      }

      aiMaterial *material = scene->mMaterials[mesh->mMaterialIndex];

      unsigned int diffuseTextureCount = aiGetMaterialTextureCount(material, aiTextureType_DIFFUSE);
      for (unsigned int i = 0; i < diffuseTextureCount; i++) {
        aiString diffuseTexturePath;
        if (aiGetMaterialTexture(material, aiTextureType_DIFFUSE, 0, &diffuseTexturePath)) {
          throw std::runtime_error("ERROR GETTING DIFFUSE TEXTURE ASSIMP");
        }

        Texture diffuseTexture{std::string(diffuseTexturePath.data)};
        textures.push_back(diffuseTexture);
      }

      // TODO: NOT good since all are being passed in as diffuse textures

      unsigned int specularTextureCount =
        aiGetMaterialTextureCount(material, aiTextureType_SPECULAR);
      for (unsigned int i = 0; i < specularTextureCount; i++) {
        aiString specularTexturePath;
        if (aiGetMaterialTexture(material, aiTextureType_SPECULAR, 0, &specularTexturePath)) {
          throw std::runtime_error("ERROR GETTING SPECULAR TEXTURE ASSIMP");
        }

        Texture specularTexture{std::string(specularTexturePath.data)};
        textures.push_back(specularTexture);
      }

      unsigned int ambientTextureCount = aiGetMaterialTextureCount(material, aiTextureType_AMBIENT);
      for (unsigned int i = 0; i < ambientTextureCount; i++) {
        aiString ambientTexturePath;
        if (aiGetMaterialTexture(material, aiTextureType_AMBIENT, 0, &ambientTexturePath)) {
          throw std::runtime_error("ERROR GETTING AMBIENT TEXTURE ASSIMP");
        }

        Texture ambientTexture{std::string(ambientTexturePath.data)};
        textures.push_back(ambientTexture);
      }

      // aiTextureType_EMISSIVE, aiTextureType_HEIGHT , aiTextureType_NORMALS,
      // aiTextureType_SHININESS, aiTextureType_DISPLACEMENT, etc.

      meshes.push_back(Mesh(vertices, indices, textures)
      );  // TODO: should be passed in without creating copy otherwise that calls the destructor
    }

    for (int i = 0; i < node->mNumChildren; i++) {
      load(scene, node->mChildren[i]);
    }
  }
};
