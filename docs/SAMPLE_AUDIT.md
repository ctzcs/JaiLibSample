# Sample audit — 2026-11-14

Scope: all 23 `olib_sample/src` entries and the additional Jai `cjk_ui` sample.
The audit compares the source workflows, runs behavior checks, reads actual GPU
pixels, and inspects screenshots. A successful launch alone is not acceptance.
The earlier audit missed net_arena presentation parity: its replacement view was
simplified. Build/network success did not establish a faithful translation. The
follow-up below restores its reference presentation and adds dedicated checks.

## Reproduce

```sh
python tools/check_samples.py --network
python ../JaiLib/tools/check/main.py --only image_bytes
python ../JaiLib/tools/check/main.py --only hdr_targets --web
python ../JaiLib/tools/check/main.py --only kit
```

The sample runner discovers all entry points, builds with `-no_dce`, stages native
DLLs, rejects compiler/assertion diagnostics even when exit status is zero, and
requires explicit success markers. Executables and logs live in
`build/check-samples/`; `results.json` records each result and screenshot path.
Screenshots are copied into separate case directories so variants cannot overwrite
one another. Without `--network`, socket checks are recorded as skipped.

Last verified: all 24 samples and five regression executables passed; the final
report contains 105 successful build/execution records (full suite plus final
focused FPS/Tween reruns). The adjacent JaiLib kit checks also passed (25 checks,
including executed world/audio regressions).

## Coverage by sample

| Sample | Exercised behavior |
| --- | --- |
| app_composition | Startup, 60 updates, shutdown and user-data release |
| backend | Bundled Noto glyph lookup, metrics and nonempty rasterized coverage |
| basic | Offscreen quad, window composition and GPU screenshot |
| batcher | Rect/circle/line output and GPU screenshot |
| book_ui | Page controls, forward/reverse turns, pause, occlusion, transformed picking, resize, keyboard activation; turn/back screenshots and narrow 125% layout |
| calc | Lerp/clamp/map values and triangulation area |
| cjk_ui | Embedded atlas, Chinese text, buttons and narrow 125% layout |
| feature | Atlas packing, every QOI/PNG pixel, alpha and 513×257 QOI dimensions |
| forward3d | Five objects, opaque/transparent ordering, lighting and zero-alpha GPU equivalence |
| game_ui | Ability/inventory/pause/settings state and narrow 125% layout |
| gizmo2d | Move/rotate/scale, multiple viewports, offset coordinates and resize |
| hotreload | Real DLL rebuild/swap, compile failure, missing exports, old callback survival, persistent position and trail |
| material2d | Explicit and automatic pass grouping, resident swarm, performance overlay and 125% scale |
| material3d | Outlines/grouping variants, resident/automatic/per-object instancing, 4× MSAA, second camera readback and performance overlay |
| meshview | Simplification, solid/wire/xray, topology counters and a generated two-primitive model translated far from the origin |
| net_arena | Reference arena/menu geometry and palette, animated blobs/eyes/stretch/trails, spinning coins/gems/glow, pickup/hit particles, score popups/shake, sorted scoreboard, results/restart; Clay Host/Join input, LAN hints, narrow layout; UDP/ENet with 80 ms lag and independent server/client processes |
| net_fps | Same connection paths, gameplay replication and 60 adversarial GPU tracer frames |
| scene_notes | Five-object viewport, add/undo/redo, resolve/reopen; separate regression for UTF-8, atomic saving, absolute paths and external-edit conflicts |
| shader_lab | All 8 shaders and 15 allocated targets, sphere/cube outlines, narrow 125% layout, pause/single-step, preset save/load/cancel, floating-point targets and bundled icons; real Dock split, undock, tab merge and redock |
| spatial | Geometry values, transforms, RGBA/ABGR packing and QOI signature |
| stylized3d | Resident scene geometry, player/camera collision invariants, terrain and rendering toggles |
| tween_preview | Trace generation, deterministic spring seeking, target selection and successful/failed DLL replacement |
| ui_gallery | Text/controls/scrolling/dialogs/focus, disabled input and GPU text/accent coverage |
| ui_motion | Card drag/drop, occupied-slot swap, hand reorder, queue execution, reward dialog, keyboard input and resize |

Additional reusable regressions cover buffer-upload ordering and Batcher merge
ranges; performance-overlay text and graph bounds across four corners, two scales,
empty/partial/full histories and hidden state; QOI opcodes and color math; and
Float16/Float32 rendering that preserves channel values of 2.0 and 4.0.

## Findings corrected

- The former net_arena view omitted most of `view.odin` and `draw2d.odin`.
  `src/net_arena/view.jai` now translates those effects, geometry, colors and
  animation parameters. `menu.jai` preserves the reference card, tabs and animated
  backdrop; `lan.jai` restores ranked LAN address hints on Windows. Text and input
  use the explicitly requested kit/Clay UI and the bundled MSDF font, rather than
  the reference's OS-dependent Segoe/Arial bitmap fonts. Optional ENet selection
  remains available below the menu. `view_checks.jai` uses deterministic replicated
  states and GPU captures for pickup, hit, dash, results and restart. Dark-overlay
  pixels catch accidental Clay color-range errors; text crosses the premultiplied
  Render2D / straight-alpha Clay boundary only once.
- Shader Lab's fixed placement prevented docking. JaiLib now ships matching
  docking source, DLL, import library and bindings, with a reproducible build in
  `tools/imgui/build.py`. Smoke tests exercise split, undock, merge and redock.
  The sample launch helper stages matching DLLs; the four affected Zed tasks use it.

- `material3d` lacked its performance overlay, and shared scene captures omitted
  the second viewport and final HUD. Captures now read the composed window.
- `hotreload` could report success without a replacement and lose the active
  module after a bad candidate. Candidate exports are validated before swapping;
  failure tests use isolated sources, and the moving square/trail is restored.
- `forward3d` used premultiplied blending for straight-alpha shader output.
  A zero-alpha object must now match omitting it, pixel for pixel.
- `meshview` assumed every input was centered at the origin and asserted at a
  simplification limit. It now fits model bounds, keeps the last usable level,
  and displays topology statistics in a Clay HUD.
- Shader Lab skipped validation of later material passes sharing target zero,
  cleared depth to zero, and omitted winding adaptation at preview upload. These caused
  failed passes, invisible models, or a solid outline shell. Every shader target
  is read back, and outlined bodies must retain colored pixels.
- Shader Lab silently downgraded declared Float16/Float32 targets to 8-bit COLOR.
  Foster now exposes and maps both formats; HDR values are verified on the GPU.
- Shader Lab's icon table was empty despite the atlas being available. Buttons
  now use the bundled atlas. Numeric/hex labels and logging argument forwarding
  were corrected; preset saves use atomic replacement and accept absolute paths.
- Scene Notes lacked search and status editing, discarded drafts on focus loss,
  and failed to save absolute paths. These paths are corrected without reading or
  changing user notes during tests.
- Color packing shifted bytes before widening, interpolation wrapped when a
  channel decreased, and hex conversion omitted byte masks. QOI encoding omitted
  alpha changes and mishandled multi-byte dimensions and signed deltas. Dedicated
  known-value and full-pixel checks now catch these errors.
- The three ImGui tools loaded a font but omitted the reference blue-gray theme
  and system-DPI scaling. Their shared host now applies the reference palette,
  rounding, spacing and physical font size. Icon buttons use measured icon/text
  bounds, and the Shader Lab panel and note editor account for the UI scale.
  Tests assert style/font metrics and read back the actual themed background.
- The gizmo probe could receive real OS pointer/key changes during its scripted
  gestures. Scripted editor input is now isolated, keeping focus changes from
  producing intermittent scaling/undo failures.
- Fresh build directories lacked runtime DLLs. `tools/stage_runtime.py` and the
  sample runner now stage the shipped dependencies explicitly.

Earlier fixes remain covered: FPS near-camera tracer clipping, Clay game HUDs,
material2d font normalization and performance graph positioning, same-frame GPU
upload ordering, and transactional note persistence.

## Boundaries

Primary sample validation uses Windows/D3D12 and injected application input.
The native-file-picker open/cancel check additionally used Windows UI automation. Shader outputs for Vulkan/MSL
are included, but this audit does not establish runtime coverage on those backends.
The Web check exercises JaiLib's existing WebGL suite, not every desktop sample.

The Windows Opus runtime is now staged with its license. Synthetic voice tests
exercise real encode, UDP/ENet RPC relay, decode and SDL playback without opening
a microphone. Human speech, physical microphone switching, and optional RNNoise
are not verified. Local networking does not validate Internet/NAT traversal.
Shader Lab now has SDL native dialogs and file-drop routing. OS automation opened
and cancelled the native file picker; selected-file replies and texture-card
drops are covered by callback-boundary/GPU tests, not an Explorer drag gesture.
The bundled ImGui is now a pinned 1.89.6 docking build with matching Jai layouts
and a startup ABI check. Shader Lab uses a real dockspace and initializes its
split only once. Docking stays inside the application window; separate OS
viewport windows are not implemented by the Foster backend.
These runtime boundaries remain explicit; they are not counted as passing tests.

The material3d resident-instancing check uses 20,000 instances. It is a correctness
check, not a one-million-instance performance benchmark. Decorative coins in
`stylized3d`, as in the reference, are not an implemented collection mechanic.

Several fixes belong to the adjacent JaiLib working tree. They must accompany
these samples; changes there are not contained in a sample-repository commit.
Foster changes are recorded in `../JaiLib/foster/docs/LOCAL_CHANGES.md`.

## Follow-up: remaining presentation and tool workflows

- Translated FPS camera-space weapon/actors, recoil, bob, muzzle and impact effects,
  reticle spread/hit/headshot feedback, damage vignette, remote interpolation,
  kill feed, scoreboard, original menu and spectator orbit. The UI uses Clay.
- Restored voice device selection, monitor/output test, speaking/level indicators,
  F1 diagnostics and logging. Fixed partial-frame capture loss and enabled sender
  echo only in `voicetest`; normal voice still excludes the local sender.
- Restored Scene Notes header/layout/reset/screenshot and 4x MSAA. Saved screenshots
  read the composed frame after rendering; tests use only build-directory note fixtures.
- Added Tween Preview project Case ID/target alias inputs, source opening and F5.
  Compiler output is drained without blocking live frames. Actual successful and
  failed DLL builds verify replacement and preservation of the live old module.
- Connected SDL native open/save callbacks and file drops to Shader Lab. Tests
  exercise request IDs, save/load/cancel, owned drop paths, card hit testing and
  uploaded texture pixels. Native picker open/cancel was also manually automated.
- Found a Jacket scalar-name collision in JaiLib quaternion conversion: `xx + zz`
  could lose the `xx` term. Renamed the terms and added three-axis orthonormality
  and combined yaw/pitch regressions. This affects 3D consumers, so the full
  sample suite was rerun rather than checking only FPS.
- The restored box-shaped tracers also cap their projected near-eye thickness.
  The adversarial 60-frame GPU regression peaks at 5,120 / 1,024,000 yellow pixels,
  preserving a visible beam without the original screen-covering polygon.
