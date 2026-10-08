# SystemInformer contributes only its `phnt` headers: a self-contained
# interface target with no dependency on SystemInformer's own CMake helpers.
# phlib and kphlib would drag that machinery in. See docs/adr/0003.

add_subdirectory(
    "${PKG_VENDOR_DIR}/systeminformer/phnt"
    "${CMAKE_BINARY_DIR}/vendor/phnt"
    EXCLUDE_FROM_ALL
)

pkg_pick_target(_phnt phnt)
pkg_include_root(_phnt_headers phnt "${PKG_VENDOR_DIR}/systeminformer/phnt/include")
pkg_stage(phnt TARGET ${_phnt} HEADERS "${_phnt_headers}")
pkg_alias(phnt ${_phnt})
