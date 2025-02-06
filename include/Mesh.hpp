// improvement -- single VBO/EBO

#include <glad/glad.h>

#include <glm/glm.hpp>
#include <stdexcept>
#include <string>
#include <vector>

#include "RenderShader.hpp"

struct Vertex {
  glm::vec3 position;
  glm::vec3 normal;
};

class Mesh {
 public:
  std::vector<Vertex> vertices;
  std::vector<unsigned int> indices;

  Mesh(std::vector<Vertex> vertices, std::vector<unsigned int> indices)
    : vertices{vertices}, indices{indices} {
    // VAO is always for a target shader (multiple VAOs can use the same shader but this isn't
    // really necessary) VAOs: track attribs
    //

    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    // doesn't have to be here necessarily (for VAO setup)
    glBufferData(GL_ARRAY_BUFFER, vertices.size() * sizeof(Vertex), &vertices[0], GL_DYNAMIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(
      GL_ELEMENT_ARRAY_BUFFER, indices.size() * sizeof(unsigned int), &indices[0], GL_STATIC_DRAW
    );

    // Can a VAO be shared across VBOs? yes

    // within the context of a single shader program because locations...
    /**
     * Shader Program {
     *   VAO {
     *     VBO {
     *       Attrib -> which location in the shader, which VBO to look at (implicitly)
     *     }
     *     VBO {
     *       Attrib -> which location in the shader, which VBO to look at (implicitly)
     *     }
     *
     *     Attribs are associated with a VBO (VBO doesn't need data during this time though)
     *     Key thing is you can define different VBOs ACROSS different attribs
     *     Then once you buffer data into those VBOs, the VAO will remember which VBOs to look at
     *     For the attribute you need
     *   }
     * } (multiple VAOs can reference this shader but likely you only need one VAO)
     *
     */

    /**
     * Everything drawn with the same shader should be batched
     * Shader requires:
     * Assume glDrawElements
     *
     *
     * [[draw call 1] [draw call 2] ...]
     */

    // must have VBO bound by here
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(
      0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, position)
    );

    glEnableVertexAttribArray(1);
    glVertexAttribPointer(
      1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)offsetof(Vertex, normal)
    );

    glBindVertexArray(0);
  }

  void draw() {
    glBindVertexArray(VAO);
    glDrawElements(GL_TRIANGLES, indices.size(), GL_UNSIGNED_INT, 0);
    glBindVertexArray(0);
  }

  void draw(int nInstances) {
    glBindVertexArray(VAO);
    glDrawElementsInstanced(GL_TRIANGLES, indices.size(), GL_UNSIGNED_INT, 0, nInstances);
    glBindVertexArray(0);
  }

 private:
  unsigned int VAO;
  unsigned int VBO;
  unsigned int EBO;
};
