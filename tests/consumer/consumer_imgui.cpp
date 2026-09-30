// imgui consumer: the member's core and its backends, on a few frames with no window.
//
// The hub promises imgui like any other member — one include root, a library staged
// per (arch, config), the static CRT — and this is the thinnest program that proves
// it: create a context, run frames, render them, and check that draw data came out.
// It is built against the published artifact, never the hub's build tree, because
// that is where a consumer meets the hub.
//
// The frame is driven by the member's do-nothing backend, which is what makes it a
// real frame rather than a stand-in: it reports
// ImGuiBackendFlags_RendererHasTextures, so the font atlas is built and grown
// dynamically and never through the legacy ImFontAtlas::Build() path that upstream
// keeps only for renderers that cannot receive texture updates. That same flag is
// why the demo window can run here — it scales fonts, which means rasterising new
// glyphs at run time and handing the resulting textures to a renderer — and it is
// why more than one frame is run before the result is judged: the atlas is created on
// one frame and grown on the next, and the windows are laid out over the same frames,
// so which one of them draws first is upstream's business and not a thing to pin.
//
// The demo and the std::string helpers are translation units of the core library, so
// calling both is what pulls them out of it: a program that calls neither leaves
// them unlinked, and the hub promises them to every consumer.
//
// The win32 and DirectX 11 parts are linked all the same, because a part's promise
// is that it can be linked: their entry points are taken at run time below, which is
// what holds that link open with no window, no swap chain and no display adapter.

#include "imgui.h"

// Each part's own header, at the spellings upstream's project files produce: the
// member's include root is flat, so these resolve beside imgui.h.
#include "imgui_impl_null.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"

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

    // Nothing this program does may outlive it: with the default ini filename the
    // demo window's settings are written as imgui.ini into whatever directory the
    // consumer is run from, and the next run would load them back — so the frame
    // would depend on the machine's leftovers instead of on the hub. A test that
    // passes because of a file it wrote last time is not testing anything.
    ImGui::GetIO().IniFilename = nullptr;

    // The do-nothing backend, one half at a time — the shape every pair of imgui
    // backends has. The platform half supplies a display size and a fixed timestep
    // for each frame, the renderer half the backend flags; neither needs a message
    // loop, a window or an adapter, which is the whole reason this can run on a
    // build machine. Upstream's own null example drives them the same way.
    if (!ImGui_ImplNullPlatform_Init() || !ImGui_ImplNullRender_Init())
    {
        std::fprintf(stderr, "imgui consumer: the do-nothing backend did not initialize\n");
        return 1;
    }

    // The default font, added before the first frame. Nothing builds the atlas by
    // hand: with a texture-capable renderer the first NewFrame() starts it, and the
    // glyphs the demo asks for at larger sizes arrive as texture updates.
    ImGui::GetIO().Fonts->AddFontDefaultVector();

    // The win32 and DirectX 11 parts, referenced and never called. A static library
    // only hands over the translation units something actually uses, so an entry
    // point that is linked is one whose part was really staged; the pointers live in
    // volatile objects on purpose, because a release build is entitled to delete a
    // reference it can see is dead, and a check that cannot fail is not a check.
    bool (*volatile win32_init)(void*) = &ImGui_ImplWin32_Init;
    void (*volatile win32_shutdown)() = &ImGui_ImplWin32_Shutdown;
    bool (*volatile dx11_init)(ID3D11Device*, ID3D11DeviceContext*) = &ImGui_ImplDX11_Init;
    void (*volatile dx11_shutdown)() = &ImGui_ImplDX11_Shutdown;

    const bool win32_dx11_linked = win32_init != nullptr && win32_shutdown != nullptr &&
                                   dx11_init != nullptr && dx11_shutdown != nullptr;

    // A texture-capable renderer meets the atlas over its first frames — created on
    // one, updated on the next — and the first windows are laid out over those same
    // frames. This program's assertion is that the member draws, not that any
    // particular frame does, so it runs a few and keeps the first one that produced
    // geometry: a count of zero from a single frame would say more about where in that
    // sequence the frame fell than about the hub. Three is comfortable today; the loop
    // is what keeps that from quietly becoming a trap.
    int drawn_frame = -1, drawn_lists = 0, drawn_vertices = 0;
    for (int frame = 0; frame < 3; ++frame)
    {
        ImGui_ImplNullPlatform_NewFrame();
        ImGui_ImplNullRender_NewFrame();
        ImGui::NewFrame();

        ImGui::Begin("consumer");
        ImGui::Text("imgui %s", IMGUI_VERSION);
        std::string text = "staged std::string helpers";
        ImGui::InputText("text", &text);
        ImGui::End();
        ImGui::ShowDemoWindow(); // the demo translation unit, fonts and all

        ImGui::Render();

        // The draw data belongs to the context, so it is read — and handed to the
        // renderer — while the context is still here.
        ImDrawData* draw_data = ImGui::GetDrawData();
        const int cmd_lists = draw_data != nullptr ? draw_data->CmdListsCount : 0;
        const int vertices = draw_data != nullptr ? draw_data->TotalVtxCount : 0;

        // The frame is rendered every time, not only the judged one: honouring the
        // texture updates is the renderer's half of the contract, and a consumer that
        // stopped feeding its renderer would be leaving the atlas in a state no real
        // frame loop ever leaves it in.
        ImGui_ImplNullRender_RenderDrawData(draw_data);

        if (vertices > 0 && drawn_frame < 0)
        {
            drawn_frame = frame;
            drawn_lists = cmd_lists;
            drawn_vertices = vertices;
        }
    }

    ImGui_ImplNullRender_Shutdown();
    ImGui_ImplNullPlatform_Shutdown();
    ImGui::DestroyContext();

    if (drawn_frame < 0)
    {
        std::fprintf(stderr, "imgui consumer: no frame produced any geometry\n");
        return 1;
    }
    if (!win32_dx11_linked)
    {
        std::fprintf(stderr, "imgui consumer: a staged backend entry point did not resolve\n");
        return 1;
    }
    std::printf("imgui consumer: %s, frame %d drew %d command list(s) / %d vertices, null platform "
                "+ renderer driving, win32 and dx11 parts linked\n",
                IMGUI_VERSION, drawn_frame, drawn_lists, drawn_vertices);
    return 0;
}
