cmake_minimum_required(VERSION 3.15)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(sph-fluid-sim LANGUAGES CXX C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

file(GLOB_RECURSE SOURCE_FILES src/*.cpp src/*.c)
add_executable(${PROJECT_NAME} ${SOURCE_FILES})

target_include_directories(${PROJECT_NAME} PRIVATE include)

find_package(assimp REQUIRED)
find_package(glad REQUIRED)
find_package(glfw3 REQUIRED)  
find_package(glm REQUIRED)
find_package(stb REQUIRED)
find_package(Tracy REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE assimp::assimp glfw glm::glm stb::stb Tracy::TracyClient)
target_link_libraries(${PROJECT_NAME} PUBLIC glad::glad)

add_custom_target(copy_assets ALL
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${PROJECT_SOURCE_DIR}/assets ${PROJECT_BINARY_DIR}/assets
  COMMENT "Copying assets into build..."
)
add_dependencies(${PROJECT_NAME} copy_assets)
