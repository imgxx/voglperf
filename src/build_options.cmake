#
# cmake -DCMAKE_BUILD_TYPE=Debug ..
#
#   http://www.cmake.org/Wiki/CMake_FAQ
#   http://www.cmake.org/Wiki/CMake_Useful_Variables
#   http://clang.llvm.org/docs/LanguageExtensions.html
#
cmake_minimum_required(VERSION 2.8)

option(BUILD_X64 "build 64-bit" FALSE)
option(CMAKE_VERBOSE "Verbose CMake" FALSE)
if( CMAKE_VERBOSE )
    SET(CMAKE_VERBOSE_MAKEFILE ON)
endif()

if( NOT BUILD_X64 )
  # If we're in our 64-bit chroot, default to 64-bit, else 32-bit
  if( "$ENV{SCHROOT_CHROOT_NAME}" STREQUAL "precise_amd64" )
    set(BUILD_X64 "TRUE")
  else()
    set(BUILD_X64 "FALSE")
  endif()
endif( NOT BUILD_X64 )

# Generate bitness suffix to use
if (BUILD_X64)
    set(CMAKE_EXECUTABLE_SUFFIX 64)
    set(CMAKE_SHARED_LIBRARY_SUFFIX "64.so")
else()
    set(CMAKE_EXECUTABLE_SUFFIX 32)
    set(CMAKE_SHARED_LIBRARY_SUFFIX "32.so")
endif()

# Default to release build
if( NOT CMAKE_BUILD_TYPE )
    set( CMAKE_BUILD_TYPE Release )
endif()

# Make sure we're using 64-bit versions of stat, fopen, etc.
# Large File Support extensions:
#   http://www.gnu.org/software/libc/manual/html_node/Feature-Test-Macros.html#Feature-Test-Macros
add_definitions(-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_LARGE_FILES)

# support for inttypes.h macros
add_definitions(-D__STDC_LIMIT_MACROS -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS)

set(CMAKE_CXX_FLAGS_LIST "-g -Wall -Wextra")
set(CMAKE_CXX_FLAGS_RELEASE_LIST "-g -O2 -DNDEBUG")
set(CMAKE_CXX_FLAGS_DEBUG_LIST "-g -O0 -D_DEBUG")

# clang doesn't print colored diagnostics when invoked from Ninja
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
  if (UNIX AND CMAKE_GENERATOR STREQUAL "Ninja")
      add_definitions ("-fcolor-diagnostics")
  endif()
endif()

if ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
  if (CLANG_EVERYTHING)
      set(CMAKE_CXX_FLAGS_LIST ${CMAKE_CXX_FLAGS_LIST}
          "-pedantic"               # Warn on language extensions
          "-fdiagnostics-show-name" # Enable display of diagnostic name
          "-Weverything"            # Enable all warnings
          "-Wno-unused-macros"
          "-Wno-padded"
          "-Wno-variadic-macros"
          )
  elseif ()
      set(CMAKE_CXX_FLAGS_LIST ${CMAKE_CXX_FLAGS_LIST}
          "--analyze"
          "-ferror-limit=0"         # Don't ever stop emitting diagnostics
          "-fshow-column"           # Print column number in diagnostic.
          "-fcaret-diagnostics"     # Print source line and ranges from source code in diagnostic
          "-pedantic"               # Warn on language extensions
          "-fdiagnostics-show-name" # Enable display of diagnostic name
          "-Weverything"            # Enable all warnings
          "-Wno-unused-macros"
          "-Wno-padded"
          "-Wno-variadic-macros"
          # "-Wno-missing-prototypes"
          )
  endif()
endif()

if (NOT BUILD_X64)
    set(CMAKE_CXX_FLAGS_LIST "${CMAKE_CXX_FLAGS_LIST} -m32")
endif()

function(add_compiler_flag flag)
    set(CMAKE_C_FLAGS    "${CMAKE_C_FLAGS}   ${flag}" PARENT_SCOPE)
    set(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} ${flag}" PARENT_SCOPE)
endfunction()

function(add_linker_flag flag)
    set(CMAKE_EXE_LINKER_FLAGS   "${CMAKE_EXE_LINKER_FLAGS} ${flag}" PARENT_SCOPE)
endfunction()

function(add_shared_linker_flag flag)
    set(CMAKE_SHARED_LINKER_FLAGS   "${CMAKE_SHARED_LINKER_FLAGS} ${flag}" PARENT_SCOPE)
endfunction()

set(MARCH_STR "-march=corei7")
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
   if ( NOT BUILD_X64 )
      # Fix startup crash in dlopen_notify_callback (called indirectly from our dlopen() function) when tracing glxspheres on my AMD dev box (x86 release only)
      # Also fixes tracing Q3 Arena using release tracer
      # Clang is generating sse2 code even when it shouldn't be:
      #  http://lists.cs.uiuc.edu/pipermail/cfe-dev/2012-March/020310.html
      set(MARCH_STR "-march=i586")
   endif()
endif()

set(CMAKE_CXX_FLAGS_LIST
    ${CMAKE_CXX_FLAGS_LIST}
    "-fno-omit-frame-pointer"
    ${MARCH_STR}
    "-Wno-unused-parameter -Wno-unused-function"
    "-fno-strict-aliasing" # DO NOT remove this, we have lots of code that will fail in obscure ways otherwise because it was developed with MSVC first.
    "-fno-math-errno"
	"-fvisibility=hidden"
    )

if (CMAKE_COMPILER_IS_GNUCC)
    execute_process(COMMAND ${CMAKE_C_COMPILER} -dumpversion OUTPUT_VARIABLE GCC_VERSION)
    string(REGEX MATCHALL "[0-9]+" GCC_VERSION_COMPONENTS ${GCC_VERSION})
    list(GET GCC_VERSION_COMPONENTS 0 GCC_MAJOR)
    list(GET GCC_VERSION_COMPONENTS 1 GCC_MINOR)
    # message(STATUS "Detected GCC v ${GCC_MAJOR} . ${GCC_MINOR}")
endif()

if (GCC_VERSION VERSION_GREATER 4.8 OR GCC_VERSION VERSION_EQUAL 4.8)
    set(CMAKE_CXX_FLAGS_LIST ${CMAKE_CXX_FLAGS_LIST}
        "-Wno-unused-local-typedefs"
    )
endif()

set(CMAKE_EXE_LINK_FLAGS_LIST
    "-Wl,--no-undefined"
    # "-lmcheck"
    )
set(CMAKE_SHARED_LINK_FLAGS_LIST
    "-Wl,--no-undefined"
    )

# Compiler flags
string(REPLACE ";" " " CMAKE_C_FLAGS              "${CMAKE_CXX_FLAGS_LIST}")
string(REPLACE ";" " " CMAKE_C_FLAGS_RELEASE      "${CMAKE_CXX_FLAGS_RELEASE_LIST}")
string(REPLACE ";" " " CMAKE_C_FLAGS_DEBUG        "${CMAKE_CXX_FLAGS_DEBUG_LIST}")

string(REPLACE ";" " " CMAKE_CXX_FLAGS            "${CMAKE_CXX_FLAGS_LIST}")
string(REPLACE ";" " " CMAKE_CXX_FLAGS_RELEASE    "${CMAKE_CXX_FLAGS_RELEASE_LIST}")
string(REPLACE ";" " " CMAKE_CXX_FLAGS_DEBUG      "${CMAKE_CXX_FLAGS_DEBUG_LIST}")

# Linker flags (exe)
string(REPLACE ";" " " CMAKE_EXE_LINKER_FLAGS     "${CMAKE_EXE_LINK_FLAGS_LIST}")
# Linker flags (shared)
string(REPLACE ";" " " CMAKE_SHARED_LINKER_FLAGS  "${CMAKE_SHARED_LINK_FLAGS_LIST}")

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/../bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/../bin)


function(build_options_finalize)
    if( CMAKE_VERBOSE )
        message("  CMAKE_PROJECT_NAME: ${CMAKE_PROJECT_NAME}")
        message("  PROJECT_NAME: ${PROJECT_NAME}")
        message("  BUILD_X64: ${BUILD_X64}")
        message("  BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
        message("  PROJECT_BINARY_DIR: ${PROJECT_BINARY_DIR}")
        message("  CMAKE_SOURCE_DIR: ${CMAKE_SOURCE_DIR}")
        message("  PROJECT_SOURCE_DIR: ${PROJECT_SOURCE_DIR}")
        message("  CMAKE_CURRENT_LIST_FILE: ${CMAKE_CURRENT_LIST_FILE}")
        message("  CXX_FLAGS: ${CMAKE_CXX_FLAGS}")
        message("  CXX_FLAGS_RELEASE: ${CMAKE_CXX_FLAGS_RELEASE}")
        message("  CXX_FLAGS_DEBUG: ${CMAKE_CXX_FLAGS_DEBUG}")
        message("  EXE_LINKER_FLAGS: ${CMAKE_EXE_LINKER_FLAGS}")
        message("  SHARED_LINKER_FLAGS: ${CMAKE_SHARED_LINKER_FLAGS}")
        message("  SHARED_LIBRARY_C_FLAGS: ${CMAKE_SHARED_LIBRARY_C_FLAGS}")
        message("  SHARED_LIBRARY_CXX_FLAGS: ${CMAKE_SHARED_LIBRARY_CXX_FLAGS}")
        message("  SHARED_LIBRARY_LINK_CXX_FLAGS: ${CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS}")
        message("  SHARED_LIBRARY_LINK_C_FLAGS: ${CMAKE_SHARED_LIBRARY_LINK_C_FLAGS}")
        message("  CMAKE_C_COMPILER: ${CMAKE_C_COMPILER}")
        message("  CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER}")
        message("  CMAKE_C_COMPILER_ID: ${CMAKE_C_COMPILER_ID}")
	message("  CMAKE_EXECUTABLE_SUFFIX: ${CMAKE_EXECUTABLE_SUFFIX}")
        message("")
    endif()
endfunction()

