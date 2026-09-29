/* Consumer smoke test, C side.
 *
 * Every include is spelled the way this hub's layout offers it: one include root
 * per member, bin/include/<member>/. Compiling and linking this file is already
 * half the test — a wrong include root, a renamed library or a CRT mismatch fails
 * here instead of in some downstream project. The other half is that the
 * libraries do something and do it correctly.
 *
 * No network, no files: every check is deterministic. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <lz4.h>
#include <mbedtls/sha256.h>
#include <quickjs.h>
#include <zlib.h>
#include <zstd.h>

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

static int failures = 0;

#define CHECK(cond)                                                          \
    do {                                                                     \
        if (cond) {                                                          \
            printf("  ok   %s:%d  %s\n", __FILE__, __LINE__, #cond);         \
        } else {                                                             \
            printf("  FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);         \
            ++failures;                                                      \
        }                                                                    \
    } while (0)

static const char *payload = "pkg hub consumer smoke test payload";

static void check_zlib(void)
{
    uLong source_len = (uLong)strlen(payload);
    uLongf compressed_len = compressBound(source_len);
    unsigned char *compressed = (unsigned char *)malloc(compressed_len);
    unsigned char *plain = (unsigned char *)malloc(source_len);

    CHECK(compressed != NULL && plain != NULL);
    if (compressed == NULL || plain == NULL) {
        free(compressed);
        free(plain);
        return;
    }

    CHECK(compress2(compressed, &compressed_len, (const Bytef *)payload, source_len,
                    Z_DEFAULT_COMPRESSION) == Z_OK);

    uLongf plain_len = source_len;
    CHECK(uncompress(plain, &plain_len, compressed, compressed_len) == Z_OK);
    CHECK(plain_len == source_len && memcmp(plain, payload, source_len) == 0);

    free(compressed);
    free(plain);
}

static void check_zstd(void)
{
    size_t source_len = strlen(payload);
    size_t bound = ZSTD_compressBound(source_len);
    void *compressed = malloc(bound);
    void *plain = malloc(source_len);

    CHECK(ZSTD_versionNumber() > 0);
    CHECK(compressed != NULL && plain != NULL);
    if (compressed == NULL || plain == NULL) {
        free(compressed);
        free(plain);
        return;
    }

    size_t compressed_len = ZSTD_compress(compressed, bound, payload, source_len, 3);
    CHECK(!ZSTD_isError(compressed_len));

    size_t plain_len = ZSTD_decompress(plain, source_len, compressed, compressed_len);
    CHECK(!ZSTD_isError(plain_len));
    CHECK(plain_len == source_len && memcmp(plain, payload, source_len) == 0);

    free(compressed);
    free(plain);
}

static void check_lz4(void)
{
    int source_len = (int)strlen(payload);
    int bound = LZ4_compressBound(source_len);
    char *compressed = (char *)malloc((size_t)bound);
    char *plain = (char *)malloc((size_t)source_len);

    CHECK(LZ4_versionNumber() > 0);
    CHECK(compressed != NULL && plain != NULL);
    if (compressed == NULL || plain == NULL) {
        free(compressed);
        free(plain);
        return;
    }

    int compressed_len = LZ4_compress_default(payload, compressed, source_len, bound);
    CHECK(compressed_len > 0);

    int plain_len = LZ4_decompress_safe(compressed, plain, compressed_len, source_len);
    CHECK(plain_len == source_len && memcmp(plain, payload, (size_t)source_len) == 0);

    free(compressed);
    free(plain);
}

static void check_mbedtls(void)
{
    /* SHA-256 of "abc" starts ba 78 16 bf. */
    static const unsigned char expected[4] = { 0xba, 0x78, 0x16, 0xbf };
    unsigned char digest[32];

    CHECK(mbedtls_sha256((const unsigned char *)"abc", 3, digest, 0) == 0);
    CHECK(memcmp(digest, expected, sizeof(expected)) == 0);
}

static void check_quickjs(void)
{
    JSRuntime *runtime = JS_NewRuntime();
    CHECK(runtime != NULL);
    if (runtime == NULL) {
        return;
    }

    JSContext *context = JS_NewContext(runtime);
    CHECK(context != NULL);
    if (context != NULL) {
        JSValue value = JS_Eval(context, "1 + 1", 5, "<smoke>", JS_EVAL_TYPE_GLOBAL);
        CHECK(!JS_IsException(value));

        int32_t result = 0;
        CHECK(JS_ToInt32(context, &result, value) == 0);
        CHECK(result == 2);

        JS_FreeValue(context, value);
        JS_FreeContext(context);
    }

    JS_FreeRuntime(runtime);
}

static void check_stb(void)
{
    /* A truncated PNG header: the decoder must fail cleanly, not crash. */
    static const unsigned char truncated_png[] = {
        0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a
    };
    int width = 0, height = 0, channels = 0;

    unsigned char *pixels = stbi_load_from_memory(truncated_png, (int)sizeof(truncated_png),
                                                  &width, &height, &channels, 4);
    CHECK(pixels == NULL);
    CHECK(stbi_failure_reason() != NULL);

    stbi_image_free(pixels);
}

int main(void)
{
    printf("consumer (C): zlib, zstd, lz4, mbedtls, quickjs, stb\n");

    check_zlib();
    check_zstd();
    check_lz4();
    check_mbedtls();
    check_quickjs();
    check_stb();

    if (failures != 0) {
        printf("consumer (C): %d check(s) failed\n", failures);
        return 1;
    }
    printf("consumer (C): all checks passed\n");
    return 0;
}
