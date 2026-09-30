# Helpers that place a vendor library inside the hub.
#
#   pkg_resolve_arch()                 -> PKG_ARCH
#   pkg_pick_target(<out> <names>...)  -> first target that exists
#   pkg_include_root(<out> <member> <root>) -> root, minus a redundant wrapper
#   pkg_stage(<member> TARGET <t> [EXTRA_TARGETS <t>...]
#                       [HEADERS <dir>...] [HEADERS_AT <subpath>=<dir|file>...]
#                       [HEADER_FILES <file>...])
#   pkg_alias(<member> <target>)
#   pkg_alias_part(<member> <part> <target>)
#
# pkg_stage() does two things for one member:
#   * binaries -> bin/lib/<member>/<arch>/<config>/
#   * headers  -> bin/include/<member>/   (this dir IS the member's include root)

# A member's include root is the directory that has to go on the include path.
# When that directory wraps exactly one subdirectory named after the member —
# curl/include/curl, magic_enum/include/magic_enum — the wrapper only repeats the
# name: descend into it, so bin/include/<member>/ holds the headers under the
# names callers actually write (curl/curl.h, magic_enum/magic_enum.hpp).
#
# Members whose root does not fit that shape are left alone on purpose:
# nlohmann/json includes itself as <nlohmann/...>, and mbedtls's root carries
# both mbedtls/ and psa/, either of which a naive descent would drop.
function(pkg_include_root out_var member root)
    file(GLOB _entries LIST_DIRECTORIES true "${root}/*")
    set(_subdirs "")
    foreach(_entry IN LISTS _entries)
        if(IS_DIRECTORY "${_entry}")
            list(APPEND _subdirs "${_entry}")
        endif()
    endforeach()

    list(LENGTH _subdirs _count)
    if(_count EQUAL 1 AND IS_DIRECTORY "${root}/${member}")
        set(${out_var} "${root}/${member}" PARENT_SCOPE)
    else()
        set(${out_var} "${root}" PARENT_SCOPE)
    endif()
endfunction()

# Normalise the architecture into the name used inside bin/lib/.
#
# The Visual Studio generator does not put the *target* architecture in
# CMAKE_SYSTEM_PROCESSOR — that variable carries the host's processor, which is how
# a Win32 configure ends up staged under x64. The platform asked for on the command
# line (CMAKE_GENERATOR_PLATFORM, i.e. -A Win32) is the truth; generators without
# that notion (Ninja) fall through to the processor.
function(pkg_resolve_arch)
    set(_platform "${CMAKE_GENERATOR_PLATFORM}")
    if(NOT _platform)
        set(_platform "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    string(TOLOWER "${_platform}" _cpu)
    if(_cpu MATCHES "^(amd64|x86_64|x64)$")
        set(_arch x64)
    elseif(_cpu MATCHES "^(arm64|aarch64)$")
        set(_arch arm64)
    elseif(_cpu MATCHES "^(win32|x86|i[3-6]86)$")
        set(_arch x86)
    else()
        set(_arch "${_cpu}")
    endif()
    set(PKG_ARCH "${_arch}" PARENT_SCOPE)
endfunction()

# Vendor CMake projects rename their targets depending on which flavours they
# built (mbedtls's static targets gain a _static suffix when shared is also on).
# We only ever configure one flavour, but pick defensively so a rename upstream
# fails with a readable message instead of a confusing one.
function(pkg_pick_target out_var)
    foreach(_candidate IN LISTS ARGN)
        if(TARGET ${_candidate})
            set(${out_var} "${_candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
    message(FATAL_ERROR "pkg: none of these targets exist: ${ARGN}")
endfunction()

function(pkg_stage member)
    cmake_parse_arguments(ARG "" "TARGET" "EXTRA_TARGETS;HEADERS;HEADERS_AT;HEADER_FILES" ${ARGN})
    if(NOT ARG_TARGET)
        message(FATAL_ERROR "pkg_stage(${member}): TARGET is required")
    endif()

    set(_targets ${ARG_TARGET} ${ARG_EXTRA_TARGETS})
    foreach(_target IN LISTS _targets)
        if(NOT TARGET ${_target})
            message(FATAL_ERROR "pkg_stage(${member}): target '${_target}' does not exist")
        endif()
        get_target_property(_type ${_target} TYPE)
        if(NOT _type STREQUAL "INTERFACE_LIBRARY")
            set_target_properties(${_target} PROPERTIES
                ARCHIVE_OUTPUT_DIRECTORY "${PKG_LIB_DIR}/${member}/${PKG_ARCH}/$<CONFIG>"
                LIBRARY_OUTPUT_DIRECTORY "${PKG_LIB_DIR}/${member}/${PKG_ARCH}/$<CONFIG>"
            )
        endif()
    endforeach()

    set(_dest "${PKG_INCLUDE_DIR}/${member}")
    set(_commands COMMAND "${CMAKE_COMMAND}" -E make_directory "${_dest}")

    foreach(_dir IN LISTS ARG_HEADERS)
        if(NOT IS_DIRECTORY "${_dir}")
            message(FATAL_ERROR "pkg_stage(${member}): header dir '${_dir}' does not exist")
        endif()
        list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_dir}" "${_dest}")
    endforeach()

    # <subpath>=<dir|file>: it lands under that subpath of the include root instead
    # of at its top level. Needed where upstream documents a nested include spelling
    # (imgui's misc/cpp/imgui_stdlib.h), which copying a directory into the root
    # cannot express. Taking a file as well as a directory is what keeps a member's
    # include root to headers: a directory is copied whole, so naming the one header
    # under it is how a source file that sits beside it stays out of the artifact.
    # A path containing '=' cannot be written this way; nothing stages one.
    foreach(_entry IN LISTS ARG_HEADERS_AT)
        string(REGEX REPLACE "=.*$" "" _subpath "${_entry}")
        string(REGEX REPLACE "^[^=]*=" "" _src "${_entry}")
        if(NOT _subpath OR NOT _src)
            message(FATAL_ERROR "pkg_stage(${member}): HEADERS_AT entry '${_entry}' is not <subpath>=<dir-or-file>")
        endif()
        if(IS_DIRECTORY "${_src}")
            list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -E make_directory "${_dest}/${_subpath}"
                                          COMMAND "${CMAKE_COMMAND}" -E copy_directory "${_src}" "${_dest}/${_subpath}")
        elseif(EXISTS "${_src}")
            list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -E make_directory "${_dest}/${_subpath}"
                                          COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${_src}" "${_dest}/${_subpath}")
        else()
            message(FATAL_ERROR "pkg_stage(${member}): HEADERS_AT entry '${_entry}' names '${_src}', which does not exist")
        endif()
    endforeach()

    if(ARG_HEADER_FILES)
        foreach(_file IN LISTS ARG_HEADER_FILES)
            if(NOT EXISTS "${_file}")
                message(FATAL_ERROR "pkg_stage(${member}): header file '${_file}' does not exist")
            endif()
        endforeach()
        list(APPEND _commands COMMAND "${CMAKE_COMMAND}" -E copy_if_different ${ARG_HEADER_FILES} "${_dest}")
    endif()

    add_custom_target(pkg_stage_${member} ALL ${_commands}
        COMMENT "Staging ${member} into bin/"
        VERBATIM
    )

    # Build the member's libraries before copying, so bin/ is never half-filled.
    foreach(_target IN LISTS _targets)
        get_target_property(_type ${_target} TYPE)
        if(NOT _type STREQUAL "INTERFACE_LIBRARY")
            add_dependencies(pkg_stage_${member} ${_target})
        endif()
    endforeach()

    # Append to the registry in the top-level scope we were included from.
    # Built with list(APPEND) so an initially empty list gains no empty element.
    set(_stages ${PKG_STAGE_TARGETS})
    list(APPEND _stages "pkg_stage_${member}")
    set(PKG_STAGE_TARGETS "${_stages}" PARENT_SCOPE)
endfunction()

function(pkg_alias member target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "pkg_alias(${member}): target '${target}' does not exist")
    endif()
    add_library(pkg::${member} ALIAS ${target})

    set(_members ${PKG_MEMBER_TARGETS})
    list(APPEND _members "pkg::${member}")
    set(PKG_MEMBER_TARGETS "${_members}" PARENT_SCOPE)
endfunction()

# A part is a member's second, third, ... library: imgui's core is the member, and
# each of its backends is a part. Parts are alternatives a consumer picks (one
# platform, one renderer), not additions everyone receives, so a part is aliased
# without joining the aggregate the hub publishes — whoever wants
# pkg::imgui_dx11 spells it, and nothing links it on their behalf.
function(pkg_alias_part member part target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "pkg_alias_part(${member} ${part}): target '${target}' does not exist")
    endif()
    add_library(pkg::${member}_${part} ALIAS ${target})
endfunction()
