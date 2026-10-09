# Frida Core DevKit — prebuilt Group C exception (docs/adr/0005).
# Pinned official binary release containing frida-core and frida-gum.

set(FRIDA_VERSION "17.23.1")

if(PKG_ARCH STREQUAL "x64")
    set(_frida_arch "x86_64")
elseif(PKG_ARCH STREQUAL "x86")
    set(_frida_arch "x86")
elseif(PKG_ARCH STREQUAL "arm64")
    set(_frida_arch "arm64")
else()
    message(FATAL_ERROR "pkg: unsupported arch '${PKG_ARCH}' for frida")
endif()

set(_frida_url "https://github.com/frida/frida/releases/download/${FRIDA_VERSION}/frida-core-devkit-${FRIDA_VERSION}-windows-${_frida_arch}.tar.xz")
set(_frida_cache_dir "${CMAKE_SOURCE_DIR}/build/_deps/frida")
set(_frida_archive "${_frida_cache_dir}/frida-core-devkit-${FRIDA_VERSION}-windows-${_frida_arch}.tar.xz")
set(_frida_extract_dir "${_frida_cache_dir}/${_frida_arch}")

if(NOT EXISTS "${_frida_extract_dir}/frida-core.lib" OR NOT EXISTS "${_frida_extract_dir}/frida-core.h")
    if(NOT EXISTS "${_frida_archive}")
        message(STATUS "pkg: downloading frida-core-devkit ${FRIDA_VERSION} (${_frida_arch})...")
        file(MAKE_DIRECTORY "${_frida_cache_dir}")
        file(DOWNLOAD "${_frida_url}" "${_frida_archive}"
            STATUS _dl_status
            TIMEOUT 180
            TLS_VERIFY ON
            SHOW_PROGRESS
        )
        list(GET _dl_status 0 _dl_code)
        if(NOT _dl_code EQUAL 0)
            file(REMOVE "${_frida_archive}")
            message(FATAL_ERROR "pkg: failed to download frida devkit from ${_frida_url}: ${_dl_status}")
        endif()
    endif()

    message(STATUS "pkg: extracting frida-core-devkit...")
    file(MAKE_DIRECTORY "${_frida_extract_dir}")
    file(ARCHIVE_EXTRACT
        INPUT "${_frida_archive}"
        DESTINATION "${_frida_extract_dir}"
    )
    if(NOT EXISTS "${_frida_extract_dir}/frida-core.h" OR NOT EXISTS "${_frida_extract_dir}/frida-core.lib")
        file(REMOVE "${_frida_archive}")
        file(REMOVE_RECURSE "${_frida_extract_dir}")
        message(FATAL_ERROR "pkg: extracted frida devkit missing frida-core.h or frida-core.lib, archive removed")
    endif()
endif()

if(NOT EXISTS "${_frida_extract_dir}/frida-core.h" OR NOT EXISTS "${_frida_extract_dir}/frida-core.lib")
    message(FATAL_ERROR "pkg: extracted frida devkit missing frida-core.h or frida-core.lib")
endif()

# Configure-time header staging for immediate consumption
file(MAKE_DIRECTORY "${PKG_INCLUDE_DIR}/frida")
file(COPY "${_frida_extract_dir}/frida-core.h" DESTINATION "${PKG_INCLUDE_DIR}/frida")

# Build-time staging target for active architecture and configuration
add_custom_target(pkg_stage_frida ALL
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${PKG_INCLUDE_DIR}/frida"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${_frida_extract_dir}/frida-core.h"
        "${PKG_INCLUDE_DIR}/frida/frida-core.h"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${PKG_LIB_DIR}/frida/${PKG_ARCH}/$<CONFIG>"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${_frida_extract_dir}/frida-core.lib"
        "${PKG_LIB_DIR}/frida/${PKG_ARCH}/$<CONFIG>/frida-core.lib"
    COMMENT "Staging frida into bin/"
    VERBATIM
)

add_custom_command(TARGET pkg_stage_frida POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E rm -f "${PKG_LIB_DIR}/frida/${PKG_ARCH}/$<CONFIG>/*.pdb"
)

list(APPEND PKG_STAGE_TARGETS pkg_stage_frida)

# Interface target and aliases
add_library(frida_core INTERFACE)
target_include_directories(frida_core INTERFACE "${PKG_INCLUDE_DIR}/frida")
target_link_libraries(frida_core INTERFACE
    "${PKG_LIB_DIR}/frida/${PKG_ARCH}/$<CONFIG>/frida-core.lib"
)

pkg_alias(frida frida_core)
add_library(pkg::frida_core ALIAS frida_core)
