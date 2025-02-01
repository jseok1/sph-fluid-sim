cmake_minimum_required(VERSION 3.15)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(fluid-sim LANGUAGES CXX C)

add_compile_definitions(_USE_MATH_DEFINES)

file(GLOB_RECURSE SOURCE_FILES src/*.cpp src/*.c)
add_executable(${PROJECT_NAME} ${SOURCE_FILES})

target_include_directories(${PROJECT_NAME} PRIVATE include)

find_package(glad REQUIRED)
find_package(glfw3 REQUIRED)  
find_package(glm REQUIRED)
target_link_libraries(${PROJECT_NAME} PRIVATE glfw glm::glm)
target_link_libraries(${PROJECT_NAME} PUBLIC glad::glad)
