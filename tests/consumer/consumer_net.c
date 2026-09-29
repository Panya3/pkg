/* Consumer smoke test, network side: curl alone, and deliberately no requests.
 *
 * curl lives in its own translation unit because curl.h pulls in the Windows
 * sockets layer: winsock2.h has to come first, and mixing that ordering into the
 * TU that also includes the other vendor headers is how the classic MSVC
 * "winsock.h already included" failure happens. */

#include <winsock2.h>

#include <curl/curl.h>
#include <stdio.h>

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

int main(void)
{
    printf("consumer (net): curl\n");

    CHECK(curl_global_init(CURL_GLOBAL_DEFAULT) == CURLE_OK);

    const char *version = curl_version();
    CHECK(version != NULL);
    if (version != NULL) {
        printf("  curl_version: %s\n", version);
    }

    const curl_version_info_data *info = curl_version_info(CURLVERSION_NOW);
    CHECK(info != NULL);
    if (info != NULL) {
        printf("  ssl_version: %s\n", info->ssl_version != NULL ? info->ssl_version : "(none)");
        /* ADR-0005: curl is configured onto Schannel, and TLS must be compiled in
         * even though the hub's mbedtls is not what backs it. */
        CHECK(info->ssl_version != NULL);
        CHECK((info->features & CURL_VERSION_SSL) != 0);
    }

    CURL *easy = curl_easy_init();
    CHECK(easy != NULL);
    if (easy != NULL) {
        CHECK(curl_easy_setopt(easy, CURLOPT_URL, "https://example.invalid/") == CURLE_OK);
        curl_easy_cleanup(easy);
    }

    curl_global_cleanup();

    if (failures != 0) {
        printf("consumer (net): %d check(s) failed\n", failures);
        return 1;
    }
    printf("consumer (net): all checks passed\n");
    return 0;
}
