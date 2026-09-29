# Helpers that place a vendor library inside the hub.
#
#   pkg_resolve_arch()              -> PKG_ARCH
#   pkg_pick_target(<out> <names>...)  -> first target that exists
#   pkg_stage(<member> TARGET <t> [EXTRA_TARGETS <t>...]
#                       [HEADERS <dir>...] [HEADER_FILES <file>...])
#   pkg_alias(<member> <target>)
#
# pkg_stage() does two things for one member:
#   * binaries -> bin/lib/<member>/<arch>/<config>/
#   * headers  -> bin/include/<member>/   (this dir IS the member's include root)

# Normalise the architecture into the name used inside bin/lib/.
function(pkg_resolve_arch)
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _cpu)
    if(_cpu MATCHES "^(amd64|x86_64|x64)$")
        set(_arch x64)
    elseif(_cpu MATCHES "^(arm64|aarch64)$")
        set(_arch arm64)
    elseif(_cpu MATCHES "^(x86|i[3-6]86)$")
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
            set(${out_var} ${_candidate} PARENT_SCOPE)
            return()
        endif()
    endforeach()
    message(FATAL_ERROR "pkg: none of these targets exist: ${ARGN}")
endfunction()

function(pkg_stage member)
    cmake_parse_arguments(ARG "" "TARGET" "EXTRA_TARGETS;HEADERS;HEADER_FILES" ${ARGN})
    if(NOT ARG_TARGET)
        message(FATAL_ERROR "pkg_stage(${member}): TARGET is required")
    endif()

    set(_targets "${ARG_TARGET};${ARG_EXTRA_TARGETS}")
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

    set(PKG_STAGE_TARGETS "${PKG_STAGE_TARGETS};pkg_stage_${member}" PARENT_SCOPE)
endfunction()

function(pkg_alias member target)
    if(NOT TARGET ${target})
        message(FATAL_ERROR "pkg_alias(${member}): target '${target}' does not exist")
    endif()
    add_library(pkg::${member} ALIAS ${target})
    set(PKG_MEMBER_TARGETS "${PKG_MEMBER_TARGETS};pkg::${member}" PARENT_SCOPE)
endfunction()
