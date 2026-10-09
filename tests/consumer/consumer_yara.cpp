// Consumer smoke test for Classic C YARA (libyara).
//
// Verifies:
//   * Staged headers under bin/include/yara resolve (<yara.h>)
//   * Staged static library links into /MD or /MDd C++ binary
//   * yr_initialize, yr_compiler_*, yr_rules_scan_mem, and yr_finalize work.

#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

#include <yara.h>

static int scan_callback(
    YR_SCAN_CONTEXT* context,
    int message,
    void* message_data,
    void* user_data)
{
    if (message == CALLBACK_MSG_RULE_MATCHING)
    {
        YR_RULE* rule = (YR_RULE*) message_data;
        std::vector<const char*>* matches = (std::vector<const char*>*) user_data;
        matches->push_back(rule->identifier);
    }
    return CALLBACK_CONTINUE;
}

int main()
{
    printf("consumer_yara: initializing libyara...\n");
    int init_res = yr_initialize();
    assert(init_res == ERROR_SUCCESS);

    YR_COMPILER* compiler = nullptr;
    int comp_res = yr_compiler_create(&compiler);
    assert(comp_res == ERROR_SUCCESS);
    assert(compiler != nullptr);

    const char* rule_source =
        "rule TestAOB {\n"
        "    strings:\n"
        "        $aob = { E8 ?? ?? ?? ?? 85 C0 74 }\n"
        "        $text = \"TargetString\"\n"
        "    condition:\n"
        "        $aob and $text\n"
        "}\n";

    int errors = yr_compiler_add_string(compiler, rule_source, nullptr);
    assert(errors == 0);

    YR_RULES* rules = nullptr;
    int rules_res = yr_compiler_get_rules(compiler, &rules);
    assert(rules_res == ERROR_SUCCESS);
    assert(rules != nullptr);

    yr_compiler_destroy(compiler);

    // Mock memory block containing matching pattern
    const uint8_t mock_memory[] = {
        0x90, 0x90,
        0xE8, 0x12, 0x34, 0x56, 0x78, 0x85, 0xC0, 0x74, 0x05, // matches $aob
        0x90, 0x90,
        'T', 'a', 'r', 'g', 'e', 't', 'S', 't', 'r', 'i', 'n', 'g', 0x00 // matches $text
    };

    std::vector<const char*> matched_rules;
    int scan_res = yr_rules_scan_mem(
        rules,
        mock_memory,
        sizeof(mock_memory),
        0,
        scan_callback,
        &matched_rules,
        0);

    assert(scan_res == ERROR_SUCCESS);
    assert(matched_rules.size() == 1);
    assert(strcmp(matched_rules[0], "TestAOB") == 0);

    printf("consumer_yara: scan passed, matched rule: %s\n", matched_rules[0]);

    yr_rules_destroy(rules);
    yr_finalize();

    printf("consumer_yara: OK\n");
    return 0;
}
