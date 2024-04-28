include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(wesnoth_internal_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(wesnoth_internal_setup_options)
  option(wesnoth_internal_ENABLE_HARDENING "Enable hardening" ON)
  option(wesnoth_internal_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    wesnoth_internal_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    wesnoth_internal_ENABLE_HARDENING
    OFF)

  wesnoth_internal_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR wesnoth_internal_PACKAGING_MAINTAINER_MODE)
    option(wesnoth_internal_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(wesnoth_internal_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(wesnoth_internal_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(wesnoth_internal_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(wesnoth_internal_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(wesnoth_internal_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(wesnoth_internal_ENABLE_PCH "Enable precompiled headers" OFF)
    option(wesnoth_internal_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(wesnoth_internal_ENABLE_IPO "Enable IPO/LTO" ON)
    option(wesnoth_internal_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(wesnoth_internal_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(wesnoth_internal_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(wesnoth_internal_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(wesnoth_internal_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(wesnoth_internal_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(wesnoth_internal_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(wesnoth_internal_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(wesnoth_internal_ENABLE_PCH "Enable precompiled headers" OFF)
    option(wesnoth_internal_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      wesnoth_internal_ENABLE_IPO
      wesnoth_internal_WARNINGS_AS_ERRORS
      wesnoth_internal_ENABLE_USER_LINKER
      wesnoth_internal_ENABLE_SANITIZER_ADDRESS
      wesnoth_internal_ENABLE_SANITIZER_LEAK
      wesnoth_internal_ENABLE_SANITIZER_UNDEFINED
      wesnoth_internal_ENABLE_SANITIZER_THREAD
      wesnoth_internal_ENABLE_SANITIZER_MEMORY
      wesnoth_internal_ENABLE_UNITY_BUILD
      wesnoth_internal_ENABLE_CLANG_TIDY
      wesnoth_internal_ENABLE_CPPCHECK
      wesnoth_internal_ENABLE_COVERAGE
      wesnoth_internal_ENABLE_PCH
      wesnoth_internal_ENABLE_CACHE)
  endif()

  wesnoth_internal_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (wesnoth_internal_ENABLE_SANITIZER_ADDRESS OR wesnoth_internal_ENABLE_SANITIZER_THREAD OR wesnoth_internal_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(wesnoth_internal_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(wesnoth_internal_global_options)
  if(wesnoth_internal_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    wesnoth_internal_enable_ipo()
  endif()

  wesnoth_internal_supports_sanitizers()

  if(wesnoth_internal_ENABLE_HARDENING AND wesnoth_internal_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR wesnoth_internal_ENABLE_SANITIZER_UNDEFINED
       OR wesnoth_internal_ENABLE_SANITIZER_ADDRESS
       OR wesnoth_internal_ENABLE_SANITIZER_THREAD
       OR wesnoth_internal_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${wesnoth_internal_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${wesnoth_internal_ENABLE_SANITIZER_UNDEFINED}")
    wesnoth_internal_enable_hardening(wesnoth_internal_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(wesnoth_internal_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(wesnoth_internal_warnings INTERFACE)
  add_library(wesnoth_internal_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  wesnoth_internal_set_project_warnings(
    wesnoth_internal_warnings
    ${wesnoth_internal_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(wesnoth_internal_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    wesnoth_internal_configure_linker(wesnoth_internal_options)
  endif()

  include(cmake/Sanitizers.cmake)
  wesnoth_internal_enable_sanitizers(
    wesnoth_internal_options
    ${wesnoth_internal_ENABLE_SANITIZER_ADDRESS}
    ${wesnoth_internal_ENABLE_SANITIZER_LEAK}
    ${wesnoth_internal_ENABLE_SANITIZER_UNDEFINED}
    ${wesnoth_internal_ENABLE_SANITIZER_THREAD}
    ${wesnoth_internal_ENABLE_SANITIZER_MEMORY})

  set_target_properties(wesnoth_internal_options PROPERTIES UNITY_BUILD ${wesnoth_internal_ENABLE_UNITY_BUILD})

  if(wesnoth_internal_ENABLE_PCH)
    target_precompile_headers(
      wesnoth_internal_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(wesnoth_internal_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    wesnoth_internal_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(wesnoth_internal_ENABLE_CLANG_TIDY)
    wesnoth_internal_enable_clang_tidy(wesnoth_internal_options ${wesnoth_internal_WARNINGS_AS_ERRORS})
  endif()

  if(wesnoth_internal_ENABLE_CPPCHECK)
    wesnoth_internal_enable_cppcheck(${wesnoth_internal_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(wesnoth_internal_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    wesnoth_internal_enable_coverage(wesnoth_internal_options)
  endif()

  if(wesnoth_internal_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(wesnoth_internal_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(wesnoth_internal_ENABLE_HARDENING AND NOT wesnoth_internal_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR wesnoth_internal_ENABLE_SANITIZER_UNDEFINED
       OR wesnoth_internal_ENABLE_SANITIZER_ADDRESS
       OR wesnoth_internal_ENABLE_SANITIZER_THREAD
       OR wesnoth_internal_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    wesnoth_internal_enable_hardening(wesnoth_internal_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
