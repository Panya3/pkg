# nlohmann/json — header-only, so there is no library to build and nothing to
# stage into bin/lib; only the include root is staged.

set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
set(JSON_Install    OFF CACHE BOOL "" FORCE)

add_subdirectory("${PKG_VENDOR_DIR}/json" "${CMAKE_BINARY_DIR}/vendor/json" EXCLUDE_FROM_ALL)

pkg_pick_target(_json nlohmann_json)
pkg_stage(json TARGET ${_json} HEADERS "${PKG_VENDOR_DIR}/json/include")
pkg_alias(json ${_json})
