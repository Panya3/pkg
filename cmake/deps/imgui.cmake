# imgui — upstream ships no CMake for the library at all: no root CMakeLists, no
# per-example one, only .vcxproj files and a Makefile. So the hub declares the
# target itself, the way it does for stb, and vendor/imgui stays read-only.
#
# The core is one library; each backend is its own part (docs/adr/0008). Upstream
# expects a caller to compile exactly the platform and renderer it uses, and most
# backends want a third-party library the hub does not vendor, so nothing here
# bundles them together.
#
# Those .vcxproj files are also where the member's include shape comes from: they
# put the repository root *and* `backends/` on the include path, which is why the
# member's include root is flat for the core and for each selected backend.

# The demo and the std::string helpers ride along with the core: they are
# translation units of the same release, and a consumer that calls neither pays
# nothing for them in a static link.
set(_imgui_core_sources
    imgui.cpp
    imgui_draw.cpp
    imgui_tables.cpp
    imgui_widgets.cpp
    imgui_demo.cpp
    misc/cpp/imgui_stdlib.cpp
)

add_library(pkg_imgui STATIC)
foreach(_source IN LISTS _imgui_core_sources)
    target_sources(pkg_imgui PRIVATE "${PKG_VENDOR_DIR}/imgui/${_source}")
endforeach()

# The same two directories the staged include root offers, so what the build sees
# and what the artifact hands out are the same thing.
target_include_directories(pkg_imgui PUBLIC
    "${PKG_VENDOR_DIR}/imgui"
    "${PKG_VENDOR_DIR}/imgui/backends"
)

# Upstream's own project files compile with /utf-8: the sources carry UTF-8 in
# comments and in the demo's string literals, which MSVC otherwise reads through
# the system code page — warning C4819, and a mojibake demo.
if(MSVC)
    target_compile_options(pkg_imgui PRIVATE /utf-8)
endif()

# Core headers flat in the include root, and the std::string helper's header at the
# subpath upstream documents it at. The header alone, not misc/cpp with it: the
# implementation is inside the core library already, and staging it beside the
# header would invite a consumer to compile a second copy of it — which is exactly
# what upstream's own note in that file tells them to do.
file(GLOB _imgui_core_headers "${PKG_VENDOR_DIR}/imgui/*.h")
pkg_stage(imgui
    TARGET pkg_imgui
    HEADER_FILES ${_imgui_core_headers}
    HEADERS_AT "misc/cpp=${PKG_VENDOR_DIR}/imgui/misc/cpp/imgui_stdlib.h"
)
pkg_alias(imgui pkg_imgui)
