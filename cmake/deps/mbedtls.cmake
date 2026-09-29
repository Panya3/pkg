# mbedtls — three static libraries (mbedtls, mbedx509, mbedcrypto) sharing one
# include root. Its `framework` submodule must be present or configure aborts.

set(ENABLE_PROGRAMS               OFF CACHE BOOL "" FORCE)
set(ENABLE_TESTING                OFF CACHE BOOL "" FORCE)
set(MBEDTLS_FATAL_WARNINGS        OFF CACHE BOOL "" FORCE)
set(USE_SHARED_MBEDTLS_LIBRARY    OFF CACHE BOOL "" FORCE)
set(USE_STATIC_MBEDTLS_LIBRARY    ON  CACHE BOOL "" FORCE)
set(DISABLE_PACKAGE_CONFIG_AND_INSTALL ON CACHE BOOL "" FORCE)

add_subdirectory("${PKG_VENDOR_DIR}/mbedtls" "${CMAKE_BINARY_DIR}/vendor/mbedtls" EXCLUDE_FROM_ALL)

pkg_pick_target(_mbedtls   mbedtls_static  mbedtls)
pkg_pick_target(_mbedx509  mbedx509_static mbedx509)
pkg_pick_target(_mbedcrypto mbedcrypto_static mbedcrypto)

pkg_stage(mbedtls TARGET ${_mbedtls}
    EXTRA_TARGETS ${_mbedx509} ${_mbedcrypto}
    HEADERS "${PKG_VENDOR_DIR}/mbedtls/include"
)

pkg_alias(mbedtls  ${_mbedtls})
pkg_alias(mbedx509 ${_mbedx509})
pkg_alias(mbedcrypto ${_mbedcrypto})
