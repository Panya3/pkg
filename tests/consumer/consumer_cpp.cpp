/* Consumer smoke test, C++ side: the header-only members.
 *
 * These stage no library, so the contract is "the headers compile and the API
 * works when included the way this hub's include roots offer them". yacppl is
 * compile-level only: its headers are small utilities with no observable
 * behaviour worth asserting. */

#include <cstdio>

#include <magic_enum.hpp>
#include <nameof.hpp>
#include <nlohmann/json.hpp>
#include <scope_guard.hpp>
#include <semver.hpp>
#include <unused.hpp>

static int failures = 0;

#define CHECK(cond)                                                          \
    do {                                                                     \
        if (cond) {                                                          \
            std::printf("  ok   %s:%d  %s\n", __FILE__, __LINE__, #cond);    \
        } else {                                                             \
            std::printf("  FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);    \
            ++failures;                                                      \
        }                                                                    \
    } while (0)

enum class channel { red, green, blue };

static void check_json(void)
{
    const auto document = nlohmann::json::parse(R"({"a": 1, "b": [2, 3]})");

    CHECK(document.at("a") == 1);
    CHECK(document.at("b").size() == 2);
    CHECK(document.dump() == "{\"a\":1,\"b\":[2,3]}");
}

static void check_magic_enum(void)
{
    CHECK(magic_enum::enum_name(channel::green) == "green");
    CHECK(magic_enum::enum_name(channel::blue) == "blue");
}

static void check_nameof(void)
{
    const auto name = nameof::nameof_type<channel>();

    std::printf("  nameof_type<channel>() = %.*s\n", (int)name.size(), name.data());
    CHECK(!name.empty());
}

static void check_semver(void)
{
    const auto version = semver::try_parse("1.2.3");

    CHECK(version.has_value());
    if (version.has_value()) {
        CHECK(version->major() == 1);
        CHECK(version->minor() == 2);
        CHECK(version->patch() == 3);
    }
}

static void check_scope_guard(void)
{
    bool executed = false;

    {
        const auto guard = scope_guard::make_scope_exit([&executed] { executed = true; });
        (void)guard;
    }

    CHECK(executed);
}

static void check_yacppl(void)
{
    nstd::unused(1, "two", 3.0);
    std::printf("  yacppl: nstd::unused compiled\n");
}

int main()
{
    std::printf("consumer (C++): json, magic_enum, nameof, semver, scope_guard, yacppl\n");

    check_json();
    check_magic_enum();
    check_nameof();
    check_semver();
    check_scope_guard();
    check_yacppl();

    if (failures != 0) {
        std::printf("consumer (C++): %d check(s) failed\n", failures);
        return 1;
    }
    std::printf("consumer (C++): all checks passed\n");
    return 0;
}
