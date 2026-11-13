// Deterministic integration checks inject input at kit/ui's public host boundary.
// This exercises the live layout and GPU renderer, but is not OS mouse/keyboard automation.
expect :: (passed: bool, label: string) {
    g.checks += 1;
    print("[ui_gallery] %: %\n", ifx passed then "PASS" else "FAIL", label);
    if !passed fail(label);
}

point_at :: (id: string, down: bool) {
    box, found := UI.ui_element_rect(*g.ui, id);
    if !found { fail(tprint("Missing widget: %", id)); return; }
    UI.ui_set_pointer(*g.ui, (box.x + box.w * 0.5) * g.scale, (box.y + box.h * 0.5) * g.scale, down);
}

smoke_input :: () {
    UI.ui_set_pointer(*g.ui, -100, -100, false);
    UI.ui_set_navigation(*g.ui, .{});
    UI.ui_set_text_edit(*g.ui, .{});
    f := g.frames;
    if f == 4 UI.ui_focus(*g.ui, "music");
    if f == 6 || f == 7 point_at("music", f == 6);
    if f == 9 UI.ui_focus(*g.ui, "volume");
    if f == 10 UI.ui_set_navigation(*g.ui, .{adjust = 2});
    if f == 12 UI.ui_focus(*g.ui, "name");
    if f == 13 UI.ui_set_text_edit(*g.ui, .{text = " Jai"});
    if f == 15 UI.ui_focus(*g.ui, "quality");
    if f == 16 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 18 UI.ui_focus(*g.ui, "quality#3");
    if f == 19 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 21 UI.ui_focus(*g.ui, "apply");
    if f == 22 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 24 UI.ui_focus(*g.ui, "reset");
    if f == 25 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 28 || f == 29 point_at("music", f == 28);
    if f == 31 UI.ui_focus(*g.ui, "cancel");
    if f == 32 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 34 UI.ui_focus(*g.ui, "reset");
    if f == 35 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 37 UI.ui_focus(*g.ui, "confirm");
    if f == 38 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 40 UI.ui_focus(*g.ui, "item-0");
    if f == 43 UI.ui_set_navigation(*g.ui, .{activate = true});
    if f == 45 {
        // Focus has scrolled the first row into view, even when the list's center is offscreen.
        point_at("item-0", false);
        UI.ui_add_scroll(*g.ui, 0, -8);
    }
    if f == 50 {
        F.window_set_size(F.App.window, .{760, 800});
        g.scale = 1.25;
        UI.ui_focus(*g.ui, "name");
    }
    if f == 62 UI.ui_set_navigation(*g.ui, .{next = 1});
    if f == 65 UI.ui_focus(*g.ui, "locked");
    if f == 66 UI.ui_set_navigation(*g.ui, .{activate = true});
}

smoke_check :: () {
    f := g.frames;
    if f == 3 capture("initial");
    if f == 8 expect(!g.music, "pointer press/release toggles music");
    if f == 11 expect(g.volume > 0.74 && g.volume < 0.76, "keyboard slider adjustment");
    if f == 14 expect(cast(string) g.name == "Player One Jai", "text input edits UTF-8 buffer");
    if f == 17 expect(g.ui.dropdown_id != 0, "dropdown opens");
    if f == 20 expect(g.quality == 3 && g.ui.dropdown_id == 0, "dropdown selects Ultra and closes");
    if f == 23 expect(g.applied == 1, "apply button activates once");
    if f == 27 {
        expect(g.dialog && g.ui.modal_id != 0, "reset opens a modal scope");
        capture("modal");
    }
    if f == 30 expect(!g.music, "modal blocks background pointer input");
    if f == 33 expect(!g.dialog && !g.music && g.quality == 3, "cancel preserves settings");
    if f == 39 expect(!g.dialog && g.music && g.quality == 1 && g.volume == 0.65, "confirm restores defaults");
    if f == 44 expect(g.selected == 0, "list item selection");
    if f == 48 {
        scrolled := false;
        for scroll: g.ui.scrolls if scroll.id == clay.ID("component-scroll").id && scroll.offset[1] < 0 scrolled = true;
        expect(scrolled, "wheel scroll changes clipped list offset");
        capture("scroll");
    }
    if f == 59 {
        box, found := UI.ui_element_rect(*g.ui, "settings-panel");
        expect(found && box.x >= 0 && box.x + box.w <= g.ui.width + 1, "narrow 125% layout stays inside viewport");
        capture("narrow-scaled");
    }
    if f == 63 expect(g.ui.focused_id == clay.ID("music").id, "Tab advances focus");
    if f == 67 expect(g.ui.focused_id != clay.ID("locked").id && g.applied == 1, "disabled control rejects focus/activation");
    if f == 72 {
        expect(g.ui.error_count == 0 && !g.ui.pool_overflow, "no layout errors or pool overflow");
        print("[ui_gallery] SMOKE PASS (% checks)\n", g.checks);
        F.app_exit();
    }
}

capture :: (label: string) {
    if !FILE.make_directory_if_it_does_not_exist("library/screenshots", true) {
        fail("Cannot create screenshot directory");
        return;
    }
    backbuffer := F.graphics_device_get_backbuffer(F.App.device, F.App.window);
    if backbuffer == null { fail("GPU backbuffer unavailable"); return; }
    texture := F.target_texture(backbuffer);
    pixels := F.image_create(texture.Width, texture.Height);
    defer F.image_destroy(*pixels);
    F.texture_get_data(texture, pixels.Data);
    light_pixels, accent_pixels: int;
    for p: pixels.Data {
        if p.r > 120 && p.g > 120 && p.b > 120 light_pixels += 1;
        if p.g > 80 && cast(int) p.g > cast(int) p.r + 30 accent_pixels += 1;
    }
    // Check both glyph-like bright pixels and the teal controls, not just a nonempty clear color.
    expect(light_pixels > 300 && accent_pixels > 100, "GPU readback contains text and accent pixels");
    bytes := F.image_encode_png(pixels);
    defer free(bytes.data);
    // Keep names distinct for each starting window/scale configuration.
    path := tprint("library/screenshots/ui-gallery-%-%-%.png", label,
        ifx g.narrow then "narrow" else "wide", ifx g.scaled then "125" else "100");
    if bytes.count == 0 || !FILE.write_entire_file(path, cast(string) bytes) { fail("PNG write failed"); return; }
    print("[ui_gallery] screenshot: %\n", path);
}
