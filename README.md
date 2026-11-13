# JaiLibSample

A collection of samples for validating the adjacent `JaiLib` checkout, following
the `src/<sample>/` layout used by `olib_sample`.
The migrated samples are `ui_gallery`, `game_ui`, `ui_motion`, `book_ui`, `gizmo2d`,
`material2d`, `cjk_ui`, `basic`, `batcher`, `app_composition`, `calc`, `spatial`,
`feature`, and `backend`.
The remaining `olib_sample` examples and their status are listed at the end.

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
jacket run -exe build/basic src/basic/main.jai
jacket run -exe build/batcher src/batcher/main.jai
jacket run -exe build/app_composition src/app_composition/main.jai
jacket run -exe build/calc src/calc/main.jai
jacket run -exe build/spatial src/spatial/main.jai
jacket run -exe build/feature src/feature/main.jai
jacket run -exe build/backend src/backend/main.jai
```

Arguments after `--` are passed to the sample. See the
[Jacket CLI documentation](https://github.com/matteopolak/jacket/blob/main/docs/tools/jacket.md)
for command syntax.

The current jfoster native library bindings load dependencies directly. Building
and running in a fresh output directory has been verified without copying DLLs
in advance. Fonts use jfoster's embedded resources; the game_ui button skin and
book_ui precompiled shaders are included in the repository and require no
downloads. The embedded Roboto font provides Latin glyphs, so sample text is in
English.

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
| `material2d` | 12 sprites sharing one two-pass material (shadow + body): pass grouping by `pass_id` or by Render2D, per-instance `hue` for the right half, camera pan/zoom, perf overlay; `swarm` switches to a resident `Sprite_Buffer` (default 1,000,000 sprites, `count=N` to resize) drawn in one instanced call; `shot` renders offscreen, `auto` lets Render2D group passes, `vulkan` picks the Vulkan driver |
| `cjk_ui` | Chinese text through `kit/ui`: the same Clay panel rendered with two fonts. `-- cjk` registers `shared/msdf_font/ui.json` + `ui.png` (Noto Sans CJK SC subset, msdf-atlas-gen 1.4, ASCII + sample Chinese vocabulary); omitting it falls back to the embedded Roboto atlas, which has no CJK glyphs |
| `basic` | Lowest-level foster sample: hand-built quad mesh, 1×1 white texture, offscreen target, and two draw commands |
| `batcher` | Direct `foster.Batcher` shapes (rect, circle, line) drawn to the window |
| `app_composition` | Application/user-data split: heap state attached to `App`, 60-frame lifetime, shutdown report |
| `calc` | `foster/utility/calc`: lerp/clamp/map, polygon triangulation, RNG, polygon area |
| `spatial` | `foster/spatial`: point/rect/line/circle/polygon math, transforms, cardinal points, QOI check |
| `feature` | `foster` image pipeline: packer pages, QOI/PNG encode–decode round trips |
| `backend` | `stb_truetype` font backend: metrics, glyph lookup, rasterized coverage bitmap |

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

## Chinese text

Two independent font paths, both verified on this machine:

- `kit/ui` (Clay) takes an **MSDF atlas**. `shared/msdf_font/` carries the
  Noto Sans CJK SC subset atlas copied from `olib_sample` (512 glyphs, 1168×1168 after the
  charset edit below), licensed OFL, `yOrigin=top`, and plugs into the existing
  `prepare_ui_font` adapter in `src/ui_gallery/font.jai`. `cjk_ui -- cjk` proves it renders.
  A glyph outside the charset renders blank, so the charset has to cover the UI vocabulary.
- `r2d` text takes a runtime **bitmap** `Sprite_Font`: `font_load` a CJK TTF/OTF and pass the
  codepoints you need (`sprite_font_create_from_font`). No offline step. Decode UTF-8 with
  `foster.rune_iterator` / `rune_next`; iterating the string byte-by-byte builds the wrong glyphs.

Regenerating the atlas (charset is `[32, 126]` plus `0xXXXX` lines, one codepoint per line):

```sh
msdf-atlas-gen -font NotoSansCJKsc-Regular.otf -charset shared/msdf_font/charset.txt   -type msdf -format png -size 48 -pxrange 8 -yorigin top -seed 0   -imageout shared/msdf_font/ui.png -json shared/msdf_font/ui.json
```

The generator is not vendored here; the copy used for this run is
`../olib/build/msdf-tools/msdf-atlas-gen/msdf-atlas-gen.exe` (1.4) with the source font at
`../olib/build/msdf-fonts/NotoSansCJKsc-Regular.otf`. The atlas PNG and JSON must stay together.

## Remaining olib_sample examples

| Sample | Status |
| --- | --- |
| `hotreload`, `tween_preview` | Blocked: both drive `core/hotreload` by compiling an Odin module into a DLL and swapping it at runtime. jacket has no shared-library output, so there is no honest Jai equivalent yet. |
| `net_arena`, `net_fps` | Blocked: need `thirdparty/onet` and `thirdparty/voice`, which JaiLib has not translated (`docs/OLIB_PARITY.md`). |
| `material3d` | Not ported yet: it needs the same Shader Lab artifacts (now working, see below) plus a `Render3D` model/instancing port (~550 lines with MSAA options, orbit camera, and a million-sphere swarm). |
| `meshview`, `forward3d`, `stylized3d` | Need per-sample 3D shaders. `kit/rendering/3d` currently ships only its own embedded shader set, so these samples cannot register custom 3D materials through the public API yet. |
| `scene_notes`, `shader_lab` | `kit/tools/scene_notes` and `kit/tools/shader_lab` are ported, but the ImGui host wiring and the Shader Lab asset set still have to be assembled in the sample. `shader_lab` also hits the manifest-registration defect above. |

The gizmo2d port keeps `editor.jai` (document transactions and viewport input)
separate from `main.jai` (host, input, and pixel drawing), matching the Odin
sample's split. Its scripted `shot` run injects pointer input inside the render
frame, so the editor sees press/move/release on the same frame as the script.
