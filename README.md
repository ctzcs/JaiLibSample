# JaiLibSample

A collection of samples for validating the adjacent `JaiLib` checkout, following
the `src/<sample>/` layout used by `olib_sample`.
The migrated samples are `ui_gallery`, `game_ui`, `ui_motion`, and `book_ui`.

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
3. jfoster's SDL_GPU pipeline uses clockwise front faces. book_ui adjusts the
   page index winding so that the two-sided shader's front face matches the
   logical front of each page. Otherwise, visible pages sample the white backing.

These adaptations live in the samples; the adjacent JaiLib / jfoster source was
not modified. Update the adapters when upstream font conventions are unified to
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

Near the end of their smoke runs, ui_motion and book_ui switch to a 760×800 window
with 125% UI scaling. Screenshots from the newer samples are saved to
`library/screenshots/<sample>-<initial-scale>-<mode>.png`.

The book_ui 3D path uses matrix and uniform data packing from `kit/world` and
`kit/rendering/3d`, together with jfoster's mesh and depth rendering interfaces.
D3D12 and Vulkan shaders are included. Local validation used D3D12; Vulkan has
not been validated. The remaining samples and features such as audio, networking,
and hot reload still need migration and validation.
