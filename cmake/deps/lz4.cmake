# lz4 — CMake entry point in build/cmake; static library comes from BUILD_STATIC_LIBS.

set(LZ4_BUILD_CLI OFF CACHE BOOL "" FORCE)

add_subdirectory("${PKG_VENDOR_DIR}/lz4/build/cmake" "${CMAKE_BINARY_DIR}/vendor/lz4" EXCLUDE_FROM_ALL)

pkg_pick_target(_lz4 lz4_static)
pkg_stage(lz4 TARGET ${_lz4}
    HEADER_FILES
        "${PKG_VENDOR_DIR}/lz4/lib/lz4.h"
        "${PKG_VENDOR_DIR}/lz4/lib/lz4hc.h"
        "${PKG_VENDOR_DIR}/lz4/lib/lz4frame.h"
        "${PKG_VENDOR_DIR}/lz4/lib/lz4frame_static.h"
        "${PKG_VENDOR_DIR}/lz4/lib/xxhash.h"
)
pkg_alias(lz4 ${_lz4})
