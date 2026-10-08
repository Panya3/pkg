# yara — Pattern matching swiss knife for malware researchers (and AOB scanning).
# Staged as a static library with /MT (Release) and /MTd (Debug).

set(_yara_sources
    libyara/ahocorasick.c
    libyara/arena.c
    libyara/atoms.c
    libyara/base64.c
    libyara/bitmask.c
    libyara/compiler.c
    libyara/endian.c
    libyara/exec.c
    libyara/exefiles.c
    libyara/filemap.c
    libyara/grammar.c
    libyara/hash.c
    libyara/hex_grammar.c
    libyara/hex_lexer.c
    libyara/lexer.c
    libyara/libyara.c
    libyara/mem.c
    libyara/modules.c
    libyara/notebook.c
    libyara/object.c
    libyara/parser.c
    libyara/proc.c
    libyara/proc/windows.c
    libyara/re.c
    libyara/re_grammar.c
    libyara/re_lexer.c
    libyara/rules.c
    libyara/scan.c
    libyara/scanner.c
    libyara/simple_str.c
    libyara/sizedstr.c
    libyara/stack.c
    libyara/stopwatch.c
    libyara/stream.c
    libyara/strutils.c
    libyara/threading.c
    libyara/modules/console/console.c
    libyara/modules/dex/dex.c
    libyara/modules/dotnet/dotnet.c
    libyara/modules/elf/elf.c
    libyara/modules/hash/hash.c
    libyara/modules/macho/macho.c
    libyara/modules/math/math.c
    libyara/modules/pe/pe.c
    libyara/modules/pe/pe_utils.c
    libyara/modules/string/string.c
    libyara/modules/tests/tests.c
    libyara/modules/time/time.c
    libyara/tlshc/tlsh.c
    libyara/tlshc/tlsh_impl.c
    libyara/tlshc/tlsh_util.c
)

add_library(yara STATIC)
foreach(_src IN LISTS _yara_sources)
    target_sources(yara PRIVATE "${PKG_VENDOR_DIR}/yara/${_src}")
endforeach()

set_target_properties(yara PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
)

target_include_directories(yara
    PUBLIC
        "${PKG_VENDOR_DIR}/yara/libyara/include"
    PRIVATE
        "${PKG_VENDOR_DIR}/yara/libyara"
        "${PKG_VENDOR_DIR}/yara"
)

target_compile_definitions(yara
    PUBLIC
        YR_BUILDING_STATIC_LIB
    PRIVATE
        _CRT_SECURE_NO_WARNINGS
        _CRT_NONSTDC_NO_DEPRECATE
        USE_WINDOWS_PROC
        HAVE_WINCRYPT_H
        DOTNET_MODULE
        DEX_MODULE
        MACHO_MODULE
        HASH_MODULE
        BUCKETS_128
        CHECKSUM_1B
)

if(MSVC)
    target_compile_options(yara PRIVATE /utf-8 /wd4005 /wd4273 /wd4090)
endif()

target_link_libraries(yara PUBLIC advapi32)

pkg_stage(yara
    TARGET yara
    HEADERS
        "${PKG_VENDOR_DIR}/yara/libyara/include"
)
pkg_alias(yara yara)
