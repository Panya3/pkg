# zstd — its CMake entry point lives in build/cmake, not at the repo root.

set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_CONTRIB  OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_SHARED   OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_STATIC   ON  CACHE BOOL "" FORCE)
set(ZSTD_USE_STATIC_RUNTIME OFF CACHE BOOL "" FORCE)

add_subdirectory("${PKG_VENDOR_DIR}/zstd/build/cmake" "${CMAKE_BINARY_DIR}/vendor/zstd" EXCLUDE_FROM_ALL)

pkg_pick_target(_zstd libzstd_static)
pkg_stage(zstd TARGET ${_zstd}
    HEADER_FILES
        "${PKG_VENDOR_DIR}/zstd/lib/zstd.h"
        "${PKG_VENDOR_DIR}/zstd/lib/zstd_errors.h"
        "${PKG_VENDOR_DIR}/zstd/lib/zdict.h"
)
pkg_alias(zstd ${_zstd})
