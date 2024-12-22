# scripts/src/memory_json/memory_json.cpp

project(memoryJson VERSION 1.0)

configure_file(memoryJsonConfig.h.in memoryJsonConfig.h)

# --------- general ---------

add_executable(memoryJson memory_json.cpp)
set_target_properties(memoryJson PROPERTIES OUTPUT_NAME memory_json)
target_link_libraries(memoryJson PUBLIC formatNumber EWWScripts_compiler_flags)
target_include_directories(
  memoryJson INTERFACE "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}
                       ../format_number> $<INSTALL_INTERFACE:include>")

# ---------- installation ---------
set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")

set_target_properties(memoryJson PROPERTIES INSTALL_RPATH
                                            "${CMAKE_INSTALL_PREFIX}")
install(TARGETS memoryJson DESTINATION bin)
