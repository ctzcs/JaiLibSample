# JaiLibSample

A collection of samples for validating the adjacent `JaiLib` checkout, following
the `src/<sample>/` layout used by `olib_sample`.
All 23 `olib_sample` examples now have runnable Jai implementations, alongside
the additional `cjk_ui` sample. The ports reproduce the main rendering, editing,
animation, and networking workflows; platform-specific differences and validation
limits are recorded below.

## Run in Zed

Open this folder, run `task: spawn` from the command palette, and select a sample.
Each sample has a single run task that calls `jacket run` directly, with no batch
scripts or separate build tasks. `jacket.toml` defines the shared import path and
uses `ui_gallery` as the default entry point.

## Requirements and command line

- Windows with a GPU and driver that support SDL_GPU.
- `jacket` on your PATH. The locally tested version is 0.35.1, installed at
  `D:\Lib\jacket-windows-x64`.
- An adjacent `../JaiLib` checkout containing the `foster` module. If it is located
  elsewhere, update `import_path` in `jacket.toml`.
- Samples and JaiLib UI/rendering modules consistently use `#import "foster"`.
  Do not mix this with a separate `#import "jfoster"`: types such as `Msdf_Font`,
  `Texture`, and `Rect` would come from different modules, causing argument type
  mismatches.

Run these commands from the project root:

```sh
jacket run -exe build/ui_gallery
jacket run -exe build/game_ui src/game_ui/main.jai
jacket run -exe build/ui_motion src/ui_motion/main.jai
jacket run -exe build/book_ui src/book_ui/main.jai
jacket run -exe build/gizmo2d src/gizmo2d/main.jai
jacket run -exe build/material2d src/material2d/main.jai
jacket run -exe build/cjk_ui src/cjk_ui/main.jai -- cjk
jacket run -exe build/hotreload src/hotreload/main.jai            # Save game/game.jai to reload
jacket run -exe build/hotreload src/hotreload/main.jai -- selftest
jacket run -exe build/basic src/basic/main.jai
jacket run -exe build/batcher src/batcher/main.jai
jacket run -exe build/app_composition src/app_composition/main.jai
jacket run -exe build/calc src/calc/main.jai
jacket run -exe build/spatial src/spatial/main.jai
jacket run -exe build/feature src/feature/main.jai
jacket run -exe build/backend src/backend/main.jai
jacket run -exe build/material3d src/material3d/main.jai
jacket run -exe build/meshview src/meshview/main.jai
jacket run -exe build/forward3d src/forward3d/main.jai
jacket run -exe build/stylized3d src/stylized3d/main.jai
jacket run -exe build/net_arena src/net_arena/main.jai
jacket run -exe build/net_fps src/net_fps/main.jai
jacket run -exe build/scene_notes src/scene_notes/main.jai
jacket run -exe build/shader_lab src/shader_lab/main.jai
jacket run -exe build/tween_preview src/tween_preview/main.jai
```

Arguments after `--` are passed to the sample. See the
[Jacket CLI documentation](https://github.com/matteopolak/jacket/blob/main/docs/tools/jacket.md)
for command syntax.

For the network arena and editor tools, the Zed tasks use a launcher that builds
and stages the paired runtime DLLs automatically:

```sh
python tools/run_sample.py net_arena
python tools/run_sample.py shader_lab
```

For direct `jacket`/`jaic` commands, stage native dependencies for a new output
directory and after updating JaiLib's native libraries:
`python tools/stage_runtime.py build`. This copies SDL3, stb and ImGui DLLs beside
the executables; a missing stb DLL can otherwise make a font sample exit before
printing anything. The automated sample checker stages its own output directory.
Latin UI fonts use Foster's embedded resources; the game_ui button skin and
book_ui precompiled shaders are included in the repository and require no
downloads. The default Roboto font provides Latin glyphs, so most sample text is in
English. The three ImGui tools use JaiLib's bundled Noto font with
explicit CJK glyph ranges. Their live compilation features require `jaic` on PATH.
Shader Lab compilation additionally requires `shadercross` and `dxc` on PATH;
the checked-in shaders allow the other rendering samples to run without them.

Player-facing menus and HUDs use **`kit/ui` (Clay)**, including `net_fps`,
`net_arena`, and `stylized3d`. Their scenes fill the game window and the HUD is
composited at the final output resolution. ImGui is reserved for the editor tools
(`scene_notes`, `shader_lab`, and `tween_preview`).
These tools share the reference blue-gray ImGui theme, bundled Noto typeface,
system-DPI scaling and matching icon-button spacing. Shader Lab uses a real ImGui
dockspace: drag tabs to split, merge or float panels within the window. Its initial
layout is a 30% left control panel and a right preview; subsequent frames preserve
user changes. JaiLib ships the matching 1.89.6 docking DLL and bindings.

`net_arena` preserves the reference's neon arena, animated character faces and
stretch, trails, spinning coins/gems, particles, score popups, hit shake, scoreboard,
round results and animated Host/Join menu. Its presentation state is local and
separate from replicated gameplay. Text/input use kit/Clay with the bundled MSDF
font. The `view-test` argument captures deterministic pickup, hit, dash and results
states and checks their pixels, including translucent overlays.

If the linker reports LNK1104 because it cannot open a sample executable, close
any running instance of that sample before trying again.

## Samples

| Sample | Features and controls |
| --- | --- |
| `ui_gallery` | UI controls, text input, list scrolling, dialogs, and keyboard focus |
| `game_ui` | Ruins scene, ability cooldowns, inventory, and pause settings; click to move, 1–6 for abilities, B for inventory, Esc to pause |
| `ui_motion` | Card dragging, action slot swapping, hand sorting, tween animations, and a reward dialog; click or Enter to enqueue, GO to execute, Esc to cancel |
| `book_ui` | Interactive six-page 3D book, curved two-sided page turns, depth occlusion, and ray picking; Left/Right to turn pages, Space to pause, right-drag to rotate, Shift+right-drag to roll, middle-drag to pan, mouse wheel to zoom, R to reset |
| `gizmo2d` | Three viewports of 2D transform gizmos (move/rotate/scale) over the same three-object session; drag handles, arrows pan, Q/E rotate camera, Z/X zoom, R reset, Ctrl+Z/Y undo/redo; `shot` runs scripted input checks |
| `material2d` | 12 sprites sharing one two-pass material (shadow + body): pass grouping by `pass_id` or by Render2D, per-instance `hue` for the right half, camera pan/zoom; P toggles the FPS/frame-time overlay. `swarm` switches to a resident `Sprite_Buffer` (default 1,000,000 sprites, `count=N` to resize) drawn in one instanced call; `shot` captures the scene and performance overlay, `scaled` renders the overlay at 125%, `auto` lets Render2D group passes, `vulkan` picks the Vulkan driver |
| `cjk_ui` | Chinese text through kit/ui using the embedded JaiLib Noto MSDF atlas by default (509 glyphs). Use `-- roboto` for an explicit Latin-font comparison; `-- cjk` remains compatible |
| `hotreload` | WASD/arrows move a square with a 24-position trail. Saving `game/game.jai` or pressing F5 rebuilds the DLL while position and trail survive. `selftest` verifies successful replacement, compile failure and missing-export fallback using isolated test sources |
| `basic` | Lowest-level foster sample: hand-built quad mesh, 1×1 white texture, offscreen target, and two draw commands |
| `batcher` | Direct `foster.Batcher` shapes (rect, circle, line) drawn to the window |
| `app_composition` | Application/user-data split: heap state attached to `App`, 60-frame lifetime, shutdown report |
| `calc` | `foster/utility/calc`: lerp/clamp/map, polygon triangulation, RNG, polygon area |
| `spatial` | `foster/spatial`: point/rect/line/circle/polygon math, transforms, cardinal points, QOI check |
| `feature` | `foster` image pipeline: packer pages, QOI/PNG encode–decode round trips |
| `backend` | `stb_truetype` font backend: metrics, glyph lookup, rasterized coverage bitmap |
| `material3d` | Two-pass outlined spheres, separate material values, grouped passes, secondary camera, MSAA, resident and automatic instancing; Space toggles outlines, G grouping, V second view, I swarm, R material reload, P performance overlay |
| `meshview` | Procedural mesh or a `.dasset` input, QEM simplification, on-screen topology statistics, solid/wire/x-ray display; A/S or Left/Right change detail, W wire, M solid, X x-ray, F fits the model bounds |
| `forward3d` | Forward lighting with directional, point, and spot lights; textured material uniforms, metallic/roughness values, depth-tested opaque objects and sorted transparent objects |
| `stylized3d` | Low-resolution meadow with shadows, water reflection, ambient occlusion, outlines, minimap, animated decorative coins, collision, and a third-person controller; WASD move, Shift sprint, Space jump, right-drag orbit, wheel zoom, R reset, P/O/E/L render toggles |
| `net_arena` | Authoritative multiplayer coin arena with prediction/rollback, bots, dash, scoring, rounds, UDP and ENet; WASD move, Space dash; host/join from the menu or CLI |
| `net_fps` | Multiplayer FPS with predicted movement, server hit validation/rewind, bots, health, respawn, scoreboard and optional spatial voice; WASD move, mouse aim, left-click fire, Space jump, Tab scoreboard, V push-to-talk, Esc releases the mouse |
| `scene_notes` | Pick world positions, edit UTF-8 notes, focus the camera, show resolved notes, undo/redo, reload, and transactional saves with external-change detection; left-click places/selects notes, right-drag orbits, wheel zooms |
| `shader_lab` | Live shader compilation and material parameters, 2D/3D previews, trail feedback, texture selection, material save/load, and Chinese labels; file requests use an in-app path dialog |
| `tween_preview` | Fly-in, spring, and hover cases; timeline seeking, parameter overrides, trace plots, two targets, and real DLL reload that preserves the current bookmark; Space play/pause, R restart, S playback speed |

The game_ui volume and music controls, and book_ui spell and item interactions,
only update demo state in memory. There is no audio playback or save system.

### ui_gallery details

- Text input, toggle, volume slider, quality dropdown, and linked progress bar.
- Apply button, disabled controls, and a reset dialog with confirm/cancel actions.
- A selectable 24-row component list, clipped inner scrolling, and outer scrolling
  for narrow windows.
- Tab / Shift+Tab to move focus, Enter to activate, and Left/Right to adjust
  sliders. Esc dismisses the dropdown, text editing, or dialog before exiting
  the application.
- UTF-8 text editing and Ctrl+V paste. Settings are kept in memory for the current
  session only.
- Default window: 1120×800. `narrow` uses 760×800; `scaled` uses 125% UI scaling;
  `shot` captures a screenshot and exits; `smoke` / `auto` runs self-checks and exits.

## Code map

| Path | Responsibility |
| --- | --- |
| `.zed/tasks.json` | One jacket run task per sample |
| `jacket.toml` | Default entry point and import paths |
| `src/ui_gallery/main.jai` | Lifecycle, input, DPI conversion, Render2D submission, and resource cleanup |
| `src/ui_gallery/view.jai` | Clay layouts, settings, list, and dialogs |
| `src/ui_gallery/font.jai` | Font metric and UV adaptation from jfoster to JaiLib UI |
| `src/ui_gallery/smoke.jai` | Deterministic input, self-checks, GPU readback, and PNG output |
| `shared/ui_sample.jai` | Shared window, font, input, scaling, and screenshot host for the newer samples |
| `src/game_ui/` | Scene, HUD, and button skin |
| `src/ui_motion/` | Card state, drag and drop, tweening, and UI |
| `src/book_ui/` | Page UI, page meshes, camera, ray picking, 3D rendering, and shaders |
| `shared/scene3d.jai`, `shared/geometry3d.jai` | 3D host, orbit camera, targets, screenshots, and reusable geometry |
| `shared/tool_host.jai` | Foster/ImGui host, CJK font setup, scaling, and tool smoke captures |
| `shared/game_host.jai`, `shared/network_menu.jai` | Clay game HUD/menu host, MSDF text, input capture, and shared connection form |
| `src/net_arena/`, `src/net_fps/` | Network sessions, authoritative simulation, prediction, RPCs, and game views |
| `tools/check_samples.py` | All 24 samples, GPU/behavior regressions, per-case logs/screenshots and optional local networking |
| `tools/build_shaders.py` | JaiLib shader extraction and SPIR-V, direct DXIL, and MSL compilation |

The rendering stack is `jfoster → kit/rendering/material → kit/rendering/2d → kit/ui`.
Controls use JaiLib's public API, and layouts use `clay.UI(..., #code {...})`.

## Integration findings

1. jfoster initializes materials lazily. Call `defaults_batch_material` before
   creating Render2D and `defaults_msdf_material` before drawing MSDF text;
   otherwise, JaiLib cannot create its built-in font material.
2. `jfoster.msdf_font_load_bytes` preserves line height in em units and atlas
   bounds in pixels, while JaiLib UI expects line height in pixels and normalized
   UVs. `font.jai` copies and normalizes the glyphs while borrowing the remaining
   resources, leaving the device-owned font unchanged. This adapter is specific
   to the embedded **top-origin Roboto** font and cannot be applied directly to
   bottom-origin fonts.
3. Instanced vertex attributes must use the semantic numbers the standard includes declare
   (`olib/instance.hlsli` starts at `TEXCOORD6`, sprites keep the corner at `TEXCOORD0`).
   SDL_GPU's D3D12 backend derives each attribute's semantic from its location, so the olib
   convention of "instance attributes at 0.. and shift the mesh attributes after them" produced
   two `TEXCOORD0` inputs and `SDL_CreateGPUGraphicsPipeline` failed with `E_INVALIDARG`.
   `sprite_instance_format` / `model_buffer_create` now emit `INSTANCE_SEMANTIC_BASE + i` and the
   draw paths bind the mesh/corner buffers unchanged.
4. `defaults_batch_material` does not set its own projection: the Batcher shader reads b0, so a
   sample that draws a raw mesh with it must upload a `Matrix4` to vertex uniform slot 0
   (`basic` uses identity because its quad is already in clip space; the Batcher path builds an
   orthographic matrix per target).
5. jfoster's SDL_GPU pipeline uses clockwise front faces. book_ui adjusts the
   page index winding so that the two-sided shader's front face matches the
   logical front of each page. Otherwise, visible pages sample the white backing.

Adaptations 1, 2 and 5 live in the samples. Adaptations 3 and 4 (and the shader-manifest
ownership fixes described in the JaiLib `docs/PORTING.md` table) are changes inside
the adjacent JaiLib checkout, kept in its working tree. Update the adapters when upstream font conventions are unified to
avoid applying normalization twice.

## Validation coverage

ui_gallery previously passed four self-check runs covering wide/narrow windows
at 100%/125% scaling. Each run includes 20 checks covering button press/release,
keyboard slider adjustment, text input, dropdown selection, Apply, modal
isolation, cancel/confirm, list selection, scrolling, runtime window shrinking,
Tab focus, disabled controls, layout error counts, and four actual GPU pixel
readbacks. `SMOKE PASS (20 checks)` in the terminal indicates a successful run;
failures return a nonzero exit code. Screenshots capture the initial, dialog,
scrolled, and narrow/scaled states.

Automated input is injected at the `kit/ui` host boundary. These are integration
tests, not operating-system mouse/keyboard automation. GPU readback provides
rendering smoke checks rather than pixel-by-pixel visual regression tests.

The newer samples also support `-- smoke`, `-- shot`, `-- scaled`, and `-- narrow`:

```sh
jacket run -exe build/book_ui src/book_ui/main.jai -- smoke scaled
jacket run -exe build/book_ui src/book_ui/main.jai -- shot turn
jacket run -exe build/game_ui src/game_ui/main.jai -- shot modal
```

- game_ui checks ability cooldowns, inventory selection, pausing, the volume
  slider, toggles, and returning from the pause menu.
- ui_motion checks dragging, swapping, sorting, queue execution, dialogs, window
  shrinking, and keyboard enqueueing.
- book_ui checks controls on all six pages, forward/backward page turns, pausing,
  boundaries, state retention, picking after orientation and zoom changes, back
  cover occlusion, keyboard controls, and actual page texture readback.

The newly ported samples were validated on this machine as follows: all twelve
samples build with `jacket build -exe build/<name> src/<name>/main.jai` (exit 0,
no `error` text); `calc`, `spatial`, `feature`, `backend`, and `app_composition`
run to a zero exit code with their expected console output; `basic`, `batcher`,
and `gizmo2d` open a window with no errors or assertions; `gizmo2d -- shot` runs
the scripted move/rotate/scale/undo/redo/resize checks and prints
`GIZMO2D SMOKE PASS`, writing `library/screenshots/gizmo2d-<w>x<h>.png` and the
post-resize capture. `material2d -- shot` renders 12 sprites through the two-pass
`SpriteShadow` material and reports `2 draws`, writing
`library/screenshots/material2d.png`; `-- shot auto` reaches the same draw count
through Render2D's automatic pass grouping; cjk_ui reports `SMOKE PASS` for its button check and
renders Chinese in `-- shot cjk`; `-- shot swarm count=20000` draws the
resident sprite buffer in one instanced call and writes
`library/screenshots/material2d-swarm.png`; a plain windowed run stays clean.
ui_gallery still reports `SMOKE PASS (20 checks)`.

Near the end of their smoke runs, ui_motion and book_ui switch to a 760×800 window
with 125% UI scaling. Screenshots from the newer samples are saved to
`library/screenshots/<sample>-<initial-scale>-<mode>.png`.

The book_ui 3D path uses matrix and uniform data packing from `kit/world` and
`kit/rendering/3d`, together with jfoster's mesh and depth rendering interfaces.
D3D12 and Vulkan shaders are included. Local validation used D3D12; Vulkan has
not been validated.

## Hot reload

`jaic` has no shared-library command-line switch, but that does not mean DLLs are impossible:
the Compiler metaprogramming API can set `Build_Options.output_type = .DYNAMIC_LIBRARY`.
`src/hotreload/build.jai` does exactly that at compile time and writes a real `.dll`
(`objdump -p` shows `game_update` / `game_version` in the export table).
The host then:

1. writes the next output name to `build/hotreload-target.txt` (the loaded DLL is mapped, so
   the linker cannot overwrite it),
2. runs `jaic` on the build script,
3. loads the new DLL, then frees the previous one, keeping host-owned game state intact.

`hotreload -- selftest` builds and loads real DLLs, checks successful replacement,
then checks compiler failure and missing exports while the previous module keeps
updating. Host position and trail history must survive every swap. Test sources
live under `build/`; the user's game source is never edited by the self-test.

## Chinese text

The CJK demo embeds `../JaiLib/assets/fonts/msdf/ui.json` and `ui.png` at
compile time: 509 glyphs, 1152 x 1152 pixels, top origin, OFL license. It works
without a special argument and from a different working directory. `-- cjk`
also enables this font in samples using `shared/ui_sample.jai`; `-- roboto`
selects Foster's Latin font for comparison. Other UI samples retain their
embedded Foster Roboto default.

The same top-origin metric/UV adapter supports both atlases. The CJK demo's text
is checked against the shipped charset; missing built-in assets fail explicitly.
Its owned decoded font is released after the UI view and GPU texture.

ImGui tool samples now load the shipped Noto OTF using a source-anchored path
instead of Microsoft YaHei from Windows. `backend` and `gizmo2d` embed that OTF;
their loader copies the bytes before transferring ownership to Foster.
The ImGui samples therefore still need the adjacent JaiLib assets at runtime.
If moving JaiLib, update both the import path and `shared/library_assets.jai`.

The older 525-glyph `shared/msdf_font` atlas remains available as a custom
resource, but is no longer a default dependency. Regeneration instructions and
licenses for the active resources live in `../JaiLib/assets/fonts/msdf/README.md`.

```sh
python tools/check_assets.py
```

This checks CJK vocabulary coverage, builds nine affected samples, exercises font
rasterization and UI/Gizmo/ImGui rendering, and runs the default CJK demo from
`build/` to verify working-directory independence. Logs are `build/asset-*.log`.
Screenshots are in `library/screenshots`; the alternate-directory CJK run writes
its capture to `build/library/screenshots`.

## Running the final nine ports

The shared 3D host supports left-drag orbit, right/middle-drag pan, wheel zoom,
F camera reset, and Esc exit. `stylized3d` uses its own third-person camera.
Examples (arguments follow `--` when using `jacket run`):

```sh
jacket run -exe build/material3d src/material3d/main.jai -- views samples=4
jacket run -exe build/material3d src/material3d/main.jai -- swarm count=20000
jacket run -exe build/material3d src/material3d/main.jai -- models each count=128
jacket run -exe build/stylized3d src/stylized3d/main.jai -- flat noao noshadow
jacket run -exe build/tween_preview src/tween_preview/main.jai -- -case=card/spring -target=scene/card-42
```

`material3d swarm` defaults to one million low-poly spheres; `count=N`,
`rings=N`, and `segments=N` control the workload. `models` selects automatic
instancing and `each` submits models individually. `samples=1/2/4/8` selects MSAA.
`tween_preview` compiles `motion.jai` into a separate DLL, watches for source
changes, and keeps the old module active if the replacement cannot compile or load.

Both network samples accept the same connection options. Build first, then open
separate terminals from this repository root, for example:

```sh
jacket build -exe build/net_fps src/net_fps/main.jai
build/net_fps.exe server port=7777 enet
build/net_fps.exe client 127.0.0.1 7777 enet
```

Use `host` for a local player and server together, `udp` or `enet` for the
transport, `bots=N` for bots, and `lag=N` for simulated latency in milliseconds.
The FPS voice path initializes when Opus is available: hold V to talk, `openmic`
sends continuously, and `voicetest` supplies a test tone. Compatible Opus/RNNoise native
libraries are needed for their respective features. Missing codecs are reported
and do not prevent the game from running.

FPS hit detection uses the authoritative eye ray. Its visible tracer starts near
the weapon and is clipped away from the camera before its thin 3D quad is built;
this prevents shots originating at or behind the eye from covering the viewport.
`net_fps -- tracer-test` (arguments after `--` with Jacket; omit `--` when running
the executable directly) checks 60 GPU frames with eye-origin, camera-crossing,
nearly parallel, and behind-camera shots. `shot menu narrow scaled` captures the
Clay connection form; `menu-test` exercises text editing, input isolation, the
transport toggle, and the Host button before checking the network session.

Scene Notes uses `content/editor/scene_notes.json` by default, or `notes=<path>`.
Its smoke run uses a separate file under `build/` and leaves user notes untouched.
Shader Lab's file dialog accepts absolute paths or paths relative to its shader
source directory. Native OS file pickers and drag-and-drop are not wired into this
host. The FPS weapon is drawn as a screen-space silhouette; the port does not
include the original voice device-selection/diagnostic panels. These examples
are functional ports, not pixel-for-pixel visual copies.

### Rebuilding shaders

```sh
python tools/build_shaders.py src/shader_lab/shaders
python tools/build_shaders.py src/stylized3d/shaders
```

The same command works with the `forward3d`, `meshview`, `net_fps`, and
`scene_notes` shader directories. It uses JaiLib's `.oshader` parser, SDL
`shadercross`, and DXC (`vs_6_0` / `ps_6_0`), keeping intermediate files in
`build/shaders`. Each `Compiled/jailib-sources.json` records SHA-256 hashes of
sources, includes, tools, and generated products. Rebuild when the corresponding
shader sources or JaiLib shader includes change.

### Additional validation and JaiLib fixes

```sh
python tools/check_samples.py
python tools/check_samples.py --network
```

The full check discovers and builds all 24 samples with `-no_dce`, runs GPU and
behavior checks, exercises multiple
material submission modes and 4x MSAA, checks narrow/scaled Shader Lab, verifies
deterministic spring seeking and successful/failed DLL replacement, tests UTF-8
note persistence and external-write conflicts, and reads pixels after multiple
buffer uploads in one frame. `--network` adds UDP and ENet runs with 80 ms
simulated latency plus independent local server/client processes for both games.
The game UI checks also cover narrow windows at 125% scale and the FPS tracer
coverage regression. With the old tracer path restored in a temporary test build,
the regression detects 489,402 yellow pixels; the restored world-space beam with near-eye width protection peaks at 5,120
of 1,024,000 pixels across the same adversarial 60-frame test on D3D12.
The performance-overlay regression checks visible text and pixel bounds for all
four corners, 100%/125% scaling, empty/partial/full history, long scope names, and
hidden overlays. Its reusable fixture lives in JaiLib's
`tests/kit/tools/perf_overlay_layout/` and is run by `tools/check_samples.py`.
It also verifies every Shader Lab shader and target, paused feedback and single
stepping, preset save/load/cancel, an imported model away from the origin,
straight-alpha blending, packed color bytes, QOI/PNG pixel round trips, and
Float16/Float32 GPU values above 1. Shader Lab uses the bundled icon atlas.
Executables, logs, `results.json` and separate screenshots for each case are under
`build/check-samples/`, avoiding running user executables in `build/`.
Use `--only meshview,shader_lab` to select samples or `--baseline` for default cases.
See [the sample audit](docs/SAMPLE_AUDIT.md) for coverage and limits.
Compiler diagnostics and explicit success markers are checked because a Jai
compiler error or assertion can otherwise leave a zero process exit code.

These checks passed on Windows/D3D12. Screenshots were also inspected for the
3D scenes and tool windows. Vulkan/MSL outputs are included but have not been
tested at runtime. Synthetic Opus encode/RPC/decode/playback now passes over UDP
and ENet; the Windows runtime and license are staged automatically. Human speech,
physical microphone switching, RNNoise, and Internet/NAT traversal remain outside
the verified coverage. The swarm
check uses 20,000 instances, not a million-instance performance benchmark.

The ports also require fixes in the adjacent **JaiLib working tree**: render-buffer
upload ordering, Batcher merge ranges, debug-line indices, ImGui texture handles
and glyph ranges, Shader Lab ownership/path/font handling, shader worker option
ownership, atomic note/preset saves, preview depth and winding, color/QOI
correctness, and floating-point texture targets. Those library changes are separate from this
sample repository and have not been committed here. Foster changes are recorded
in `../JaiLib/foster/docs/LOCAL_CHANGES.md`; their pixel regression lives under
`../JaiLib/foster/tests/upload_order/`.

The gizmo2d port keeps `editor.jai` (document transactions and viewport input)
separate from `main.jai` (host, input, and pixel drawing), matching the Odin
sample's split. Its scripted `shot` run injects pointer input inside the render
frame, so the editor sees press/move/release on the same frame as the script.

### Reference workflow adaptations

- **net_fps** now uses the reference camera-space gun, recoil, muzzle flash,
  spread/hit/headshot reticles, damage edges, remote interpolation/hit flashes,
  kill feed, scoreboard and orbiting spectator camera. Menu and HUD use kit/Clay.
  The world-space tracer keeps a near-camera clip and projected-width limit.
- **Voice:** `V` talks, `F1` opens diagnostics; with the mouse released, `M` cycles
  inputs, `O` cycles/tests outputs, and `L` monitors the microphone. `mic <name>`
  and `out <name>` match device names; `voicetest` generates a synthetic tone and
  echoes it through the server. Partial microphone frames are retained, playback
  keeps a 60 ms lead, and departed speakers are released. Diagnostics are written
  to `build/net-fps-voice.log`. See [Opus provenance/license](assets/voice/README.md).
- **scene_notes** restores the separate header, scene and notes panel, reference
  camera reset, 4x MSAA and screenshot action. Captures include the composed UI,
  use unique filenames, and populate the screenshot field of an open draft.
- **tween_preview** accepts a Case ID and target alias in the project entry UI,
  opens case source files, and rebuilds with `F5`. Runtime compilation is polled
  asynchronously; the previous module keeps playing until a valid candidate is
  ready, then replays from the start with the same selection/speed; failed
  compilation preserves the running module.
- **shader_lab** uses SDL native open/save dialogs and forwards owned file-drop
  paths and coordinates to texture cards. Callback replies are applied on the
  render thread with the original request ID; stale replies cannot select a new
  parameter accidentally.

These changes also need the adjacent JaiLib quaternion fix and audio-device API.
The quaternion regression checks rotated basis lengths, orthogonality and the
combined FPS aim direction; smoke tests cover asynchronous reload recovery,
callback save/load/cancel, drop-to-texture GPU pixels and Opus network loopback.
