# Consumer smoke test.
#
# This project deliberately imports NOTHING from the hub's own CMake: it reads the
# staged output under bin/ the way another project would. It is configured and
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
    string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _cpu)
    if(_cpu MATCHES "^(amd64|x86_64|x64)$")
        set(PKG_ARCH x64)
    elseif(_cpu MATCHES "^(arm64|aarch64)$")
        set(PKG_ARCH arm64)
    elseif(_cpu MATCHES "^(x86|i[3-6]86)$")
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

# Every member the hub promises, and which of them must ship a library.
set(PKG_MEMBERS
    zlib zstd lz4 mbedtls curl quickjs
    json phnt stb magic_enum nameof scope_guard semver yacppl
)
set(PKG_LIBRARY_MEMBERS zlib zstd lz4 mbedtls curl quickjs)

foreach(_member IN LISTS PKG_MEMBERS)
    if(NOT IS_DIRECTORY "${PKG_INCLUDE_DIR}/${_member}")
        message(FATAL_ERROR "pkg_consumer: no staged headers for '${_member}' under ${PKG_INCLUDE_DIR}")
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
