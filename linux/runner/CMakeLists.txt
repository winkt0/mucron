cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "mic_stream_plugin.cpp"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
#target_link_libraries(${BINARY_NAME} PRIVATE flutter)
#target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
find_package(X11 REQUIRED)
target_link_libraries(${BINARY_NAME} PRIVATE flutter PkgConfig::GTK X11::X11)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Add this near your existing sources:
set(LINUX_PLUGIN_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/mic_stream_plugin.cpp"
)

# If you want a header-only include path for miniaudio:
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/third_party)

# Make sure these sources are added to the runner build:
target_sources(${BINARY_NAME} PRIVATE
  ${LINUX_PLUGIN_SOURCES}
)

# Link with pthread if your toolchain requires it (usually already linked)
find_package(Threads)
if(Threads_FOUND)
  target_link_libraries(${BINARY_NAME} PRIVATE Threads::Threads)
endif()
