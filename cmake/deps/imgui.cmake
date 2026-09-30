# imgui — upstream ships no CMake for the library at all: no root CMakeLists, no
# per-example one, only .vcxproj files and a Makefile. So the hub declares the
# target itself, the way it does for stb, and vendor/imgui stays read-only.
#
# The core is one library; each backend is its own part (docs/adr/0008). Upstream
# expects a caller to compile exactly the platform and renderer it uses, and most
# backends want a third-party library the hub does not vendor, so nothing here
# bundles them together.
#
# Which backends exist is a configure-time decision: they are alternatives a
# consumer picks — one platform, one renderer — so a build pays only for the ones it
# names. Every backend in the table below reaches no further than the Windows SDK,
# which is why the hub can stage all of them in the published artifact.
#
# Those .vcxproj files are also where the member's include shape comes from: they
# put the repository root *and* `backends/` on the include path, which is why the
# member's include root is flat for the core and for each selected backend.

# The demo and the std::string helpers ride along with the core: they are
# translation units of the same release, and a consumer that calls neither pays
# nothing for them in a static link.
#
# The targets carry upstream's own names, `imgui` and `imgui_impl_<backend>`, and
# nothing of the hub's: a staged library is named after its target and the name it
# ships under is one a consumer reads, so pkg_ — which belongs to targets the hub
# declares for its own bookkeeping — must not appear in it. The name a consumer
# spells for a part is the pkg:: alias below, and there the hub's scheme is exactly
# right: pkg::imgui, pkg::imgui_win32.
set(_imgui_core_sources
    imgui.cpp
    imgui_draw.cpp
    imgui_tables.cpp
    imgui_widgets.cpp
    imgui_demo.cpp
    misc/cpp/imgui_stdlib.cpp
)

add_library(imgui STATIC)
foreach(_source IN LISTS _imgui_core_sources)
    target_sources(imgui PRIVATE "${PKG_VENDOR_DIR}/imgui/${_source}")
endforeach()

# The same two directories the staged include root offers, so what the build sees
# and what the artifact hands out are the same thing.
target_include_directories(imgui PUBLIC
    "${PKG_VENDOR_DIR}/imgui"
    "${PKG_VENDOR_DIR}/imgui/backends"
)

# Upstream's own project files compile with /utf-8: the sources carry UTF-8 in
# comments and in the demo's string literals, which MSVC otherwise reads through
# the system code page — warning C4819, and a mojibake demo.
if(MSVC)
    target_compile_options(imgui PRIVATE /utf-8)
endif()

# The backends the hub knows how to build, and the single place that says so. Each
# name is spelled the way upstream spells the file — backends/imgui_impl_<name>.cpp
# beside its header — and each one's dependencies stop at the Windows SDK, which is
# the only reason the hub can build it for someone else. win32 is the platform
# backend, the DirectX and OpenGL ones are renderers, and null is both halves at
# once: a consumer takes a platform and a renderer from this set.
#
# A backend that needs a library the hub does not vendor is not in this table at
# all: GLFW, SDL2, SDL3, Vulkan, WebGPU, Allegro, GLUT, and the platform backends of
# Android, Apple, OSX and QNX. While such a library is not a member, "unavailable"
# is the honest answer — a name the hub cannot build is a configure error rather
# than a library that quietly is not there.
set(_imgui_backends win32 dx9 dx10 dx11 dx12 opengl2 opengl3 null)

# Which of them this build stages. Read, and checked, before a single target exists
# for them: a backend left out is not a target at all, so nothing is compiled and
# nothing is staged for it — "not selected" means absent, not merely uninstalled.
# The default is the whole table: every backend the hub can build reaches no further
# than the Windows SDK, so a build with no option set stages all of them.
set(PKG_IMGUI_BACKENDS "${_imgui_backends}" CACHE STRING
    "imgui backends to stage, semicolon-separated; every backend whose dependencies stop at the Windows SDK (cmake/deps/imgui.cmake lists them)")

foreach(_backend IN LISTS PKG_IMGUI_BACKENDS)
    if(NOT _backend IN_LIST _imgui_backends)
        string(REPLACE ";" " " _accepted "${_imgui_backends}")
        message(FATAL_ERROR
            "pkg: PKG_IMGUI_BACKENDS names '${_backend}', which is not an imgui backend; "
            "accepted backends: ${_accepted}")
    endif()
endforeach()

# One target per selected backend, each a part of this member rather than a member
# of its own: the alias is published for whoever spells it, and it is deliberately
# not added to the hub's aggregate, because a backend is an alternative a consumer
# picks — one platform, one renderer — and not an addition everyone receives.
set(_imgui_backend_targets "")
set(_imgui_backend_headers "")
foreach(_backend IN LISTS PKG_IMGUI_BACKENDS)
    add_library(imgui_impl_${_backend} STATIC
        "${PKG_VENDOR_DIR}/imgui/backends/imgui_impl_${_backend}.cpp")
    # The core, PUBLIC, so the part compiles against the same headers a consumer
    # sees and a consumer who names only the backend still gets the core's library
    # and its include root. A part depends on the core and never on another part,
    # so nothing here can put two renderers on one link line.
    target_link_libraries(imgui_impl_${_backend} PUBLIC imgui)
    pkg_alias_part(imgui ${_backend} imgui_impl_${_backend})

    list(APPEND _imgui_backend_targets imgui_impl_${_backend})
    list(APPEND _imgui_backend_headers
         "${PKG_VENDOR_DIR}/imgui/backends/imgui_impl_${_backend}.h")
endforeach()

# Core headers flat in the include root, each backend's header beside them, and the
# std::string helper's header at the subpath upstream documents it at. The header
# alone, not misc/cpp with it: the implementation is inside the core library
# already, and staging it beside the header would invite a consumer to compile a
# second copy of it — which is exactly what upstream's own note in that file tells
# them to do.
#
# The backends go through EXTRA_TARGETS rather than a staging call of their own:
# a part's library belongs in the member's library directory, beside the core,
# because that is the directory a consumer reads. Nothing is staged for a backend
# that was never created, which is what makes the selection option's "not selected"
# mean absent rather than uninstalled.
file(GLOB _imgui_core_headers "${PKG_VENDOR_DIR}/imgui/*.h")
pkg_stage(imgui
    TARGET imgui
    EXTRA_TARGETS ${_imgui_backend_targets}
    HEADER_FILES ${_imgui_core_headers} ${_imgui_backend_headers}
    HEADERS_AT "misc/cpp=${PKG_VENDOR_DIR}/imgui/misc/cpp/imgui_stdlib.h"
)
pkg_alias(imgui imgui)
