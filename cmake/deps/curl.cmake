# curl — the only member that depends on other libraries. It looks those up with
# find_package (filesystem search), which cannot see targets we added with
# add_subdirectory, so it is configured to need nothing outside Windows itself:
# Schannel for TLS and no zlib/zstd. See docs/adr/0005.

set(BUILD_CURL_EXE       OFF CACHE BOOL "" FORCE)
set(CURL_DISABLE_INSTALL ON  CACHE BOOL "" FORCE)
# Ask curl for the static CRT in its own words too; it appends -MT/-MTd itself.
set(CURL_STATIC_CRT      ON  CACHE BOOL "" FORCE)
set(CURL_DISABLE_LDAP    ON  CACHE BOOL "" FORCE)

# Anything that would trigger find_package(... REQUIRED) for a library we are not
# staging into a prefix must be off, or configure aborts.
set(CURL_USE_LIBPSL      OFF CACHE BOOL "" FORCE)
set(CURL_USE_LIBSSH2     OFF CACHE BOOL "" FORCE)
set(CURL_USE_OPENSSL     OFF CACHE BOOL "" FORCE)
set(CURL_USE_MBEDTLS     OFF CACHE BOOL "" FORCE)
set(CURL_USE_SCHANNEL    ON  CACHE BOOL "" FORCE)
set(CURL_ZLIB            OFF CACHE BOOL "" FORCE)
set(CURL_ZSTD            OFF CACHE BOOL "" FORCE)

add_subdirectory("${PKG_VENDOR_DIR}/curl" "${CMAKE_BINARY_DIR}/vendor/curl" EXCLUDE_FROM_ALL)

pkg_pick_target(_curl libcurl_static libcurl)
pkg_include_root(_curl_headers curl "${PKG_VENDOR_DIR}/curl/include")
pkg_stage(curl TARGET ${_curl} HEADERS "${_curl_headers}")
pkg_alias(curl ${_curl})
