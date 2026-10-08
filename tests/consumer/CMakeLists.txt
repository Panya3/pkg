# Consumer smoke test.
#
# This project deliberately imports NOTHING from the hub's own CMake: it reads the
# staged output under bin/ the way another project would. One thing it does share with
# the hub is members.txt, the roster of which members exist (see the roster below):
# the project promises the artifact carries every member, so it cannot keep its own
# list of them and still be able to disagree with the artifact. It is configured and
# built after the hub, and what it proves is the contract the hub hands out:
#
#   * every member stages the headers it promises, under an include root that
#     actually resolves the include spelling the layout offers
#   * every library member stages linkable .lib files under <arch>/<config>
#   * the staged libraries link into an executable built with the same CRT
#     (/MT, /MTd) — a mismatch fails here as LNK2038 instead of downstream
#   * the libraries really work: compress/decompress, hash, parse, eval
#
#   cmake -S tests/consumer -B build/consumer -DPKG_CONFIG=Debug
#   cmake --build build/consumer --config Debug
#   ./build/consumer/Debug/consumer_c.exe

cmake_minimum_required(VERSION 3.25)

project(pkg_consumer LANGUAGES C CXX)

# What any consumer of this hub has to do as well: match its CRT. The hub ships
# /MT (/MTd), so a consumer built /MD fails at link time on purpose.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/$<CONFIG>")

# Which staged config to consume. CI passes the config it just built; a local run
# defaults to Debug.
if(NOT PKG_CONFIG)
    if(CMAKE_BUILD_TYPE)
        set(PKG_CONFIG "${CMAKE_BUILD_TYPE}")
    else()
        set(PKG_CONFIG Debug)
    endif()
endif()

# Derived here rather than passed in on purpose: if the hub's bin/lib layout
# changes shape, this test is supposed to be the thing that notices.
if(NOT PKG_ARCH)
    # Same trap as the hub's own resolver: the VS generator reports the host
    # processor here, so the platform asked for with -A wins when there is one.
    if(CMAKE_GENERATOR_PLATFORM)
        set(_processor "${CMAKE_GENERATOR_PLATFORM}")
    else()
        set(_processor "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    string(TOLOWER "${_processor}" _cpu)
    if(_cpu MATCHES "^(amd64|x86_64|x64)$")
        set(PKG_ARCH x64)
    elseif(_cpu MATCHES "^(arm64|aarch64)$")
        set(PKG_ARCH arm64)
    elseif(_cpu MATCHES "^(win32|x86|i[3-6]86)$")
        set(PKG_ARCH x86)
    else()
        set(PKG_ARCH "${_cpu}")
    endif()
endif()

if(NOT PKG_BIN_DIR)
    set(PKG_BIN_DIR "${CMAKE_CURRENT_LIST_DIR}/../../bin")
endif()
set(PKG_INCLUDE_DIR "${PKG_BIN_DIR}/include")
set(PKG_LIB_DIR     "${PKG_BIN_DIR}/lib")

if(NOT IS_DIRECTORY "${PKG_INCLUDE_DIR}")
    message(FATAL_ERROR "pkg_consumer: '${PKG_INCLUDE_DIR}' does not exist — build the hub first")
endif()

# Every member the hub promises, and which of them must ship a library — read from the
# hub's roster rather than kept a second time here, because a list this project kept
# itself could promise a member the artifact does not carry, and a member added to the
# hub would be promised by nobody until someone remembered this file. members.txt is
# the same file the workflow's staged-tree and installer checks read, so all of them
# move together. PKG_MEMBERS_FILE names a different roster for a consumer that keeps
# one of its own; the format is one member per line, `lib` marking the ones that stage
# a library beside their headers.
if(NOT PKG_MEMBERS_FILE)
    set(PKG_MEMBERS_FILE "${CMAKE_CURRENT_LIST_DIR}/../../members.txt")
endif()
if(NOT EXISTS "${PKG_MEMBERS_FILE}")
    message(FATAL_ERROR "pkg_consumer: no member roster at '${PKG_MEMBERS_FILE}'")
endif()

set(PKG_MEMBERS "")
set(PKG_LIBRARY_MEMBERS "")
# Read rather than file(STRINGS): that command rewrites the lines it decides are not
# plain text, and a comment carrying a dash — like this one — is one of them, arriving
# split in two with the dash gone, which is a roster entry nobody wrote. A CMake list is
# semicolon-separated as well, so the file's own semicolons are escaped until the lines
# have been separated: a comment is otherwise enough to invent a member.
file(READ "${PKG_MEMBERS_FILE}" _roster_text)
string(REPLACE "\r\n" "\n" _roster_text "${_roster_text}")
string(REPLACE ";" "\\;" _roster_text "${_roster_text}")
string(REPLACE "\n" ";" _roster_lines "${_roster_text}")
foreach(_line IN LISTS _roster_lines)
    string(REPLACE "\\;" ";" _line "${_line}")
    # Comment and blank lines carry no member; the whitespace between a name and its
    # flag is alignment, so it is collapsed before the line is split.
    string(STRIP "${_line}" _line)
    if(_line STREQUAL "" OR _line MATCHES "^#")
        continue()
    endif()
    string(REGEX REPLACE "[ \t]+" " " _line "${_line}")
    string(REPLACE " " ";" _fields "${_line}")
    list(GET _fields 0 _member)
    list(APPEND PKG_MEMBERS "${_member}")
    list(LENGTH _fields _field_count)
    if(_field_count GREATER 1)
        list(GET _fields 1 _flag)
        if(NOT _flag STREQUAL "lib")
            message(FATAL_ERROR
                "pkg_consumer: member '${_member}' carries unknown flag '${_flag}' in "
                "${PKG_MEMBERS_FILE}; the roster names a member and, for the ones that "
                "stage a library, 'lib'")
        endif()
        list(APPEND PKG_LIBRARY_MEMBERS "${_member}")
    endif()
endforeach()

# A roster that names nothing reads as every check passing, which is the one failure
# this project must not have: it exists to be the thing that notices a missing member.
if(NOT PKG_MEMBERS)
    message(FATAL_ERROR "pkg_consumer: '${PKG_MEMBERS_FILE}' names no members")
endif()

foreach(_member IN LISTS PKG_MEMBERS)
    if(NOT IS_DIRECTORY "${PKG_INCLUDE_DIR}/${_member}")
        message(FATAL_ERROR "pkg_consumer: no staged headers for '${_member}' under ${PKG_INCLUDE_DIR}")
    endif()
endforeach()

# The same promise for the half of the roster that ships one: a member the hub says
# stages a library has to have staged one in the column being consumed, whether or not
# any program below happens to link it.
foreach(_member IN LISTS PKG_LIBRARY_MEMBERS)
    file(GLOB _staged "${PKG_LIB_DIR}/${_member}/${PKG_ARCH}/${PKG_CONFIG}/*.lib")
    if(NOT _staged)
        message(FATAL_ERROR
            "pkg_consumer: '${_member}' stages a library, and "
            "${PKG_LIB_DIR}/${_member}/${PKG_ARCH}/${PKG_CONFIG} holds none")
    endif()
endforeach()

message(STATUS "pkg_consumer: consuming ${PKG_BIN_DIR} (${PKG_ARCH}, ${PKG_CONFIG})")

# Link whatever the member staged for this config. Globbing is on purpose: the
# hub renames libraries per config (zlib ships zsd.lib in Debug, zs.lib in
# Release), and the consumer should not have to know that.
function(pkg_consumer_link name)
    foreach(_member IN LISTS ARGN)
        file(GLOB _staged "${PKG_LIB_DIR}/${_member}/${PKG_ARCH}/${PKG_CONFIG}/*.lib")
        if(NOT _staged)
            message(FATAL_ERROR
                "pkg_consumer: '${_member}' staged no library in "
                "${PKG_LIB_DIR}/${_member}/${PKG_ARCH}/${PKG_CONFIG}")
        endif()
        target_link_libraries(${name} PRIVATE ${_staged})
    endforeach()
endfunction()

# --- C side: the C libraries -----------------------------------------------
add_executable(consumer_c consumer_c.c)
target_include_directories(consumer_c PRIVATE
    "${PKG_INCLUDE_DIR}/zlib" "${PKG_INCLUDE_DIR}/zstd" "${PKG_INCLUDE_DIR}/lz4"
    "${PKG_INCLUDE_DIR}/mbedtls" "${PKG_INCLUDE_DIR}/quickjs" "${PKG_INCLUDE_DIR}/stb")
pkg_consumer_link(consumer_c zlib zstd lz4 mbedtls quickjs)
# mbedtls asks for these itself when it is a CMake target; linking the staged
# files directly means we supply them.
target_link_libraries(consumer_c PRIVATE ws2_32 bcrypt)

# --- C side: curl (own TU, so winsock2.h can come first) --------------------
add_executable(consumer_net consumer_net.c)
target_include_directories(consumer_net PRIVATE "${PKG_INCLUDE_DIR}/curl")
# The hub stages the static libcurl, and a static curl is a compile-time fact:
# without CURL_STATICLIB, curl.h declares every entry point __declspec(dllimport)
# and the link fails on __imp_curl_*. Part of the contract, not a workaround.
target_compile_definitions(consumer_net PRIVATE CURL_STATICLIB)
pkg_consumer_link(consumer_net curl)
# Linking the staged files means the consumer supplies curl's Windows system
# libraries. This is exactly the list curl's own CMake appends for a Schannel
# build with LDAP and IDN off: SSPI brings secur32 and iphlpapi, the crypto path
# brings advapi32/crypt32/bcrypt.
target_link_libraries(consumer_net PRIVATE ws2_32 iphlpapi bcrypt advapi32 crypt32 secur32)

# --- C side: phnt (headers only, compile-level contract) --------------------
add_executable(consumer_phnt consumer_phnt.c)
target_include_directories(consumer_phnt PRIVATE "${PKG_INCLUDE_DIR}/phnt")

# --- C++ side: the header-only members --------------------------------------
add_executable(consumer_cpp consumer_cpp.cpp)
target_include_directories(consumer_cpp PRIVATE
    "${PKG_INCLUDE_DIR}/json" "${PKG_INCLUDE_DIR}/magic_enum" "${PKG_INCLUDE_DIR}/nameof"
    "${PKG_INCLUDE_DIR}/scope_guard" "${PKG_INCLUDE_DIR}/semver" "${PKG_INCLUDE_DIR}/yacppl")

# --- C++ side: imgui (a member that stages libraries) ------------------------
# imgui is not one library: the core and each backend are separate staged
# libraries in the member's directory, so the glob above links the core beside the
# parts. One of them drives the frame — the do-nothing backend, since a build
# machine has no window and no GPU — and the win32 and DirectX 11 parts are
# referenced at run time instead, which is what forces those two staged libraries
# to link as well. The file's comment says why the frame needs no window.
add_executable(consumer_imgui consumer_imgui.cpp)
target_include_directories(consumer_imgui PRIVATE "${PKG_INCLUDE_DIR}/imgui")
pkg_consumer_link(consumer_imgui imgui)
# Linking the staged files means the consumer supplies the Windows system
# libraries the backends it uses need, exactly as it already supplies ws2_32 for
# curl: user32 and gdi32 for the win32 platform, and d3d11, dxgi and d3dcompiler
# for the DirectX 11 renderer. (The platform backend also wants dwmapi, which
# upstream's own source asks for with a #pragma, so it names itself.) The hub
# stages libraries, not link interfaces, so this list belongs here. The other
# renderers staged beside these need no entry: nothing here refers to them, so
# none of theirs is taken out of the archive and none of them is linked in.
target_link_libraries(consumer_imgui PRIVATE user32 gdi32 d3d11 dxgi d3dcompiler)
