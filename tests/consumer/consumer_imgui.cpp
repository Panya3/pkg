// imgui consumer: the member's core, with no backend, no window and no GPU.
//
// The hub promises imgui like any other member — one include root, a library
// staged per (arch, config), the static CRT — and this is the thinnest program
// that proves it: create a context, load the default font, run a frame, render it,
// and check that draw data came out. It is built against the published artifact,
// never the hub's build tree, because that is where a consumer meets the hub.
//
// No backend is linked here, so the font atlas is built by hand. Upstream keeps
// ImFontAtlas::Build() for exactly that case: a renderer that does not support
// ImGuiBackendFlags_RendererHasTextures. It has to run before the first NewFrame()
// — with no texture-capable backend the atlas locks on that first frame, and
// NewFrame() checks that a legacy atlas was built. A program that wants real
// output drives a backend instead, the way upstream's own headless example drives
// its do-nothing backend; the absence of one is this program's whole point.

#include "imgui.h"

// The std::string helper is part of the member's contract, spelling and all: the
// hub stages its header at the subpath upstream documents, and its implementation
// is inside the staged core library. Calling it below is what proves both, since
// nothing else in this program would pull that translation unit out of the library.
#include "misc/cpp/imgui_stdlib.h"

#include <cstdio>
#include <string>

int main()
{
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(640.0f, 480.0f); // NewFrame() lays out against a surface...
    io.DeltaTime = 1.0f / 60.0f;             // ...and asserts on a zero delta.

    io.Fonts->AddFontDefaultVector();
    io.Fonts->Build();

    ImGui::NewFrame();
    ImGui::Begin("consumer");
    ImGui::Text("imgui %s", IMGUI_VERSION);
    std::string text = "staged std::string helpers";
    ImGui::InputText("text", &text);
    ImGui::End();
    ImGui::Render();

    // Read the draw data before the context goes: it belongs to the context.
    const int cmd_lists = ImGui::GetDrawData() != nullptr ? ImGui::GetDrawData()->CmdListsCount : 0;
    ImGui::DestroyContext();

    if (cmd_lists == 0)
    {
        std::fprintf(stderr, "imgui consumer: no draw command lists were produced\n");
        return 1;
    }
    std::printf("imgui consumer: %s, %d draw command list(s)\n", IMGUI_VERSION, cmd_lists);
    return 0;
}
