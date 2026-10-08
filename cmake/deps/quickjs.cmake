# quickjs-ng — `qjs` plus the separate `qjs-libc` object library.

set(QJS_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set(QJS_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(QJS_BUILD_WERROR   OFF CACHE BOOL "" FORCE)

add_subdirectory("${PKG_VENDOR_DIR}/quickjs" "${CMAKE_BINARY_DIR}/vendor/quickjs" EXCLUDE_FROM_ALL)

pkg_pick_target(_qjs qjs)
pkg_stage(quickjs TARGET ${_qjs}
    HEADER_FILES
        "${PKG_VENDOR_DIR}/quickjs/quickjs.h"
        "${PKG_VENDOR_DIR}/quickjs/quickjs-atom.h"
        "${PKG_VENDOR_DIR}/quickjs/quickjs-opcode.h"
        "${PKG_VENDOR_DIR}/quickjs/quickjs-c-atomics.h"
        "${PKG_VENDOR_DIR}/quickjs/quickjs-libc.h"
)
pkg_alias(quickjs ${_qjs})

# Built unless QJS_BUILD_LIBC folds the libc into libqjs itself.
if(TARGET qjs-libc)
    pkg_stage(quickjs-libc TARGET qjs-libc)
    pkg_alias(quickjs-libc qjs-libc)
endif()
