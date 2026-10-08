/* Consumer smoke test, Windows-native side: phnt is headers only.
 *
 * There is nothing to link and nothing to call, so compiling this file and
 * reading the native types it declares is the whole contract. It still earns its
 * place: phnt drags in the Windows headers, which is where include-order
 * breakage shows up. */

#include <phnt_windows.h>
#include <phnt.h>

#include <stdio.h>

int main(void)
{
    UNICODE_STRING name;

    name.Length = 0;
    name.MaximumLength = 0;
    name.Buffer = NULL;

    printf("consumer (phnt): UNICODE_STRING is %u bytes\n", (unsigned)sizeof(UNICODE_STRING));
    printf("consumer (phnt): compiled against the staged phnt headers\n");
    printf("consumer (phnt): all checks passed\n");
    return 0;
}
