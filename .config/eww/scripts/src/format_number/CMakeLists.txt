# scripts/src/format_number/CMakeLists.txt

project(formatNumber VERSION 1.0)

configure_file(formatNumberConfig.h.in formatNumberConfig.h)

# --------- general ----------

# library
add_library(formatNumber SHARED format_number.cpp)
set_target_properties(formatNumber PROPERTIES OUTPUT_NAME format_number)
target_link_libraries(formatNumber PUBLIC EWWScripts_compiler_flags)

target_include_directories(
  formatNumber INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}
                         $<INSTALL_INTERFACE:include>)

# executable
add_executable(formatNumber_main format_number_main.cpp)
set_target_properties(formatNumber_main PROPERTIES OUTPUT_NAME format_number)
target_link_libraries(formatNumber_main PUBLIC formatNumber
                                               EWWScripts_compiler_flags)
target_include_directories(
  formatNumber
  INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}
            ${CMAKE_CURRENT_BINARY_DIR} $<INSTALL_INTERFACE:include lib>)

# -------- installation ----------
# RPATH setup
set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}")
set(CMAKE_INSTALL_RPATH "${CMAKE_SOURCE_DIR}/lib")
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)

# library
install(TARGETS formatNumber DESTINATION lib)
install(FILES format_number.h
              ${CMAKE_BINARY_DIR}/src/format_number/formatNumberConfig.h
        DESTINATION include)

# executable
install(TARGETS formatNumber_main DESTINATION bin)
set_target_properties(formatNumber_main PROPERTIES INSTALL_RPATH
                                                   "${CMAKE_INSTALL_RPATH}")
