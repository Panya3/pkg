# The Neargye collection — five header-only libraries, each with its own
# CMakeLists. Their build/tests/install options default to PROJECT_IS_TOP_LEVEL,
# which is already false here; set them explicitly so a future default change
# cannot quietly pull examples into the hub.

set(MAGIC_ENUM_OPT_BUILD_EXAMPLES   OFF CACHE BOOL "" FORCE)
set(MAGIC_ENUM_OPT_BUILD_TESTS      OFF CACHE BOOL "" FORCE)
set(MAGIC_ENUM_OPT_INSTALL          OFF CACHE BOOL "" FORCE)
set(NAMEOF_OPT_BUILD_EXAMPLES       OFF CACHE BOOL "" FORCE)
set(NAMEOF_OPT_BUILD_TESTS          OFF CACHE BOOL "" FORCE)
set(NAMEOF_OPT_INSTALL              OFF CACHE BOOL "" FORCE)
set(SCOPE_GUARD_OPT_BUILD_EXAMPLES  OFF CACHE BOOL "" FORCE)
set(SCOPE_GUARD_OPT_BUILD_TESTS     OFF CACHE BOOL "" FORCE)
set(SCOPE_GUARD_OPT_INSTALL         OFF CACHE BOOL "" FORCE)
set(SEMVER_OPT_BUILD_EXAMPLES       OFF CACHE BOOL "" FORCE)
set(SEMVER_OPT_BUILD_TESTS          OFF CACHE BOOL "" FORCE)
set(SEMVER_OPT_INSTALL              OFF CACHE BOOL "" FORCE)
set(YACPPL_OPT_BUILD_EXAMPLES       OFF CACHE BOOL "" FORCE)
set(YACPPL_OPT_BUILD_TESTS          OFF CACHE BOOL "" FORCE)

foreach(_member magic_enum nameof scope_guard semver yacppl)
    add_subdirectory(
        "${PKG_VENDOR_DIR}/neargye/${_member}"
        "${CMAKE_BINARY_DIR}/vendor/neargye/${_member}"
        EXCLUDE_FROM_ALL
    )
    pkg_pick_target(_target ${_member})
    # magic_enum wraps its headers in include/magic_enum/, which pkg_include_root
    # unwraps; the other four sit flat in include/.
    pkg_include_root(_headers ${_member} "${PKG_VENDOR_DIR}/neargye/${_member}/include")
    pkg_stage(${_member} TARGET ${_target} HEADERS "${_headers}")
    pkg_alias(${_member} ${_target})
endforeach()
