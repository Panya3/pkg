# stb — no CMakeLists upstream, so the hub declares the interface target itself.
# The source tree is still read-only: nothing is written next to vendor/stb.

add_library(pkg_stb INTERFACE)
target_include_directories(pkg_stb INTERFACE "${PKG_VENDOR_DIR}/stb")

file(GLOB _stb_headers "${PKG_VENDOR_DIR}/stb/*.h")
pkg_stage(stb TARGET pkg_stb HEADER_FILES ${_stb_headers})
pkg_alias(stb pkg_stb)
