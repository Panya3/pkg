# pkg — lib hub: pin third-party libraries in vendor/ and build them into bin/.
#
# Vocabulary lives in CONTEXT.md, the decisions behind this shape in docs/adr/.
# Nothing under vendor/ is ever edited: each member is brought in with
# add_subdirectory(... EXCLUDE_FROM_ALL) plus options set in cmake/deps/.

cmake_minimum_required(VERSION 3.25)

project(pkg LANGUAGES C CXX)

# ---------------------------------------------------------------------------
# Global defaults, set as cache variables *before* any add_subdirectory so a
# vendor's own default loses to ours.
# ---------------------------------------------------------------------------
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries only" FORCE)
set(BUILD_STATIC_LIBS ON  CACHE BOOL "Build static libraries" FORCE)
set(BUILD_TESTING     OFF CACHE BOOL "Never build a vendor's tests" FORCE)

# Static CRT: /MT for release-style configs, /MTd for Debug. Static libraries are
# only half of "self-contained" — the runtime they link is the other half, and a
# consumer built with /MD cannot mix with these. See docs/adr/0006.
set(_pkg_msvc_runtime_library "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(CMAKE_MSVC_RUNTIME_LIBRARY "${_pkg_msvc_runtime_library}"
    CACHE STRING "MSVC runtime library (static CRT)" FORCE)
# The cache entry alone can be shadowed in some generator paths, so bind it in
# this scope too: subdirectories inherit it and read it when creating targets.
set(CMAKE_MSVC_RUNTIME_LIBRARY "${_pkg_msvc_runtime_library}")

# ---------------------------------------------------------------------------
# Layout of the staged hub
# ---------------------------------------------------------------------------
set(PKG_VENDOR_DIR  "${CMAKE_CURRENT_SOURCE_DIR}/vendor")
set(PKG_BIN_DIR     "${CMAKE_CURRENT_SOURCE_DIR}/bin")
set(PKG_INCLUDE_DIR "${PKG_BIN_DIR}/include")  # bin/include/<member>/  (that dir is the include root)
set(PKG_LIB_DIR     "${PKG_BIN_DIR}/lib")      # bin/lib/<member>/<arch>/<config>/

# The hub's own installer travels inside the hub: the copy at the repository root
# is the source, and the one that matters sits in bin/ beside include/ and lib/,
# which is where a consumer who unpacks the artifact finds it. Copied rather than
# generated, so all four columns carry a byte-identical file — the published merge
# is flat and would otherwise let one column's copy win silently.
file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/Install.bat" DESTINATION "${PKG_BIN_DIR}")
# Without this the copy above would keep being the old file until something else
# re-configured, which is how a hub ends up shipping yesterday's search path.
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
             "${CMAKE_CURRENT_SOURCE_DIR}/Install.bat")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(PkgStage)

pkg_resolve_arch()                             # -> PKG_ARCH: x64 / arm64 / x86

# Members record themselves here as the glue files below are included.
set(PKG_MEMBER_TARGETS "")
set(PKG_STAGE_TARGETS "")

# ---------------------------------------------------------------------------
# Members — dependency group A, plus phnt (see docs/adr/0003).
# Each file: vendor options -> add_subdirectory -> pkg_stage -> pkg_alias.
# Group C members without a CMakeLists of their own (luajit, detours) are not
# part of this build on purpose; see docs/adr/0004.
# ---------------------------------------------------------------------------
include(cmake/deps/zlib.cmake)
include(cmake/deps/zstd.cmake)
include(cmake/deps/lz4.cmake)
include(cmake/deps/mbedtls.cmake)
include(cmake/deps/curl.cmake)
include(cmake/deps/quickjs.cmake)
include(cmake/deps/json.cmake)
include(cmake/deps/neargye.cmake)
include(cmake/deps/phnt.cmake)
include(cmake/deps/stb.cmake)
include(cmake/deps/imgui.cmake)
include(cmake/deps/yara.cmake)

# ---------------------------------------------------------------------------
# The hub's surface
# ---------------------------------------------------------------------------
# pkg_all (the default target) is complete once every member is staged: each
# pkg_stage_* target already depends on the libraries it stages.
add_custom_target(pkg_all ALL DEPENDS ${PKG_STAGE_TARGETS})

add_library(pkg_hub INTERFACE)
target_link_libraries(pkg_hub INTERFACE ${PKG_MEMBER_TARGETS})
add_library(pkg::hub ALIAS pkg_hub)

message(STATUS "pkg: staging members (${PKG_ARCH}) into ${PKG_BIN_DIR}")
