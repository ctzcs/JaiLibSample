#load "../../shared/ui_sample.jai";
#load "geometry.jai";
#load "renderer.jai";
#load "pages.jai";
#load "smoke.jai";

spread, direction: int;
progress: float32;
turn_seconds: float32 = 0.95;
paused: bool;
focus_page: int = 1;
status: string = "Choose a spell, mark a page, or turn the leaf.";
main :: () { sample_run("book_ui", 1180, 860); }
sample_start :: () {
    reset_pose(); renderer_start(); pages_start();
    h.theme.primary = .{47,103,88,255}; h.theme.primary_hover = .{57,122,102,255}; h.theme.accent = .{119,193,162,255};
    if has_arg("back") spread = 1;
    if has_arg("turn") { begin_turn(1); progress = 0.42; paused = true; }
}
sample_stop :: () { pages_stop(); renderer_stop(); }
begin_turn :: (way: int) {
    if direction != 0 || spread + way < 0 || spread + way > 2 return;
    direction = way; progress = 0;
    for *page: pages { page.ctx.active_id = 0; page.ctx.focused_id = 0; }
}
sample_update :: () {
    // Tab/Enter belong to the focused paper page; do not also activate the overlay.
    UI.ui_set_navigation(*h.ui, .{});
    if !h.smoke {
        keyboard := F.input_keyboard(F.App.input);
        if F.keyboard_pressed(keyboard, .ESCAPE) F.app_exit();
        if F.keyboard_pressed(keyboard, .SPACE) paused = !paused;
        if F.keyboard_pressed(keyboard, .RIGHT) begin_turn(1);
        if F.keyboard_pressed(keyboard, .LEFT) begin_turn(-1);
    }
    if direction != 0 && !paused {
        progress += h.dt / turn_seconds;
        if progress >= 1 { spread += direction; direction = 0; progress = 0; focus_page = spread * 2 + 1; }
    }
    update_view();
}
sample_draw :: () {
    root_element();
    C.UI(anchor("heading", 28, 24, h.ui.width - 56), #code {
        label("THE FIELD GRIMOIRE", 28, .{229,220,190,255});
        label("Click the paper / Arrows: turn / Space: pause / Tab + Enter: page controls", 13, h.theme.text_dim);
        label("Right drag: rotate / Shift: roll / Middle drag: move / Wheel: depth / R: reset", 13, h.theme.text_dim);
    });
    C.UI(anchor("controls", 28, h.ui.height - 126, h.ui.width - 56), #code {
        label(status, 14, .{190,203,193,255});
        C.UI(UI.ui_row_decl(10), #code {
            if UI.ui_button(*h.ui, *h.theme, "previous", "< Previous", .{disabled = spread == 0 || direction != 0}) begin_turn(-1);
            label(tprint("% - % / 6", spread * 2 + 1, spread * 2 + 2), 15, h.theme.text);
            if UI.ui_button_ex(*h.ui, *h.theme, "next", "Next >", .Primary, .{disabled = spread == 2 || direction != 0}) begin_turn(1);
            if h.ui.width > 850 {
                UI.ui_spacer();
                if UI.ui_button(*h.ui, *h.theme, "reset-view", "Reset view") reset_pose();
                if UI.ui_button(*h.ui, *h.theme, "pause", ifx paused then "Resume" else "Pause") paused = !paused;
                UI.ui_slider(*h.ui, *h.theme, "duration", *turn_seconds, 0.5, 2, width = 130);
            }
        });
        if h.ui.width <= 850 C.UI(UI.ui_row_decl(10), #code {
            if UI.ui_button(*h.ui, *h.theme, "reset-view", "Reset view") reset_pose();
            if UI.ui_button(*h.ui, *h.theme, "pause", ifx paused then "Resume" else "Pause") paused = !paused;
            UI.ui_slider(*h.ui, *h.theme, "duration", *turn_seconds, 0.5, 2, width = 130);
        });
        label(ifx direction != 0 then "Turning leaf / page input locked until landing" else tprint("3D perspective + depth / Turn duration: % s", turn_seconds), 12, h.theme.text_dim);
    });
}
sample_after_ui :: () {
    manipulate(); update_view();
    sheets[0] = make_sheet(PI, 0); sheets[1] = make_sheet(0, 0);
    if direction != 0 {
        t := progress * progress * (3 - 2 * progress);
        sheets[2] = make_sheet(ifx direction > 0 then PI * t else PI * (1 - t), sin(PI * t) * 0.85 * cast(float32) direction, 0.35);
    }
    blocked := UI.ui_input_capture(*h.ui).pointer || direction != 0 || drag_mode != 0;
    hit: int = -1; uv: F.Vector2;
    if !blocked hit, uv = pick_book(h.pointer * h.scale);
    if hit >= 0 && h.down focus_page = hit;
    for *page, i: pages {
        p: F.Vector2 = .{-1000,-1000}; if i == hit p = .{uv.x * PAGE_W, uv.y * PAGE_H};
        UI.ui_set_pointer(*page.ctx, p.x, p.y, h.down);
        if i != hit page.ctx.active_id = 0;
        nav: UI.UI_Navigation;
        if !blocked && i == focus_page {
            keyboard := F.input_keyboard(F.App.input);
            if F.keyboard_pressed(keyboard, .TAB) nav.next = ifx F.keyboard_shift(keyboard) then -1 else 1;
            nav.activate = F.keyboard_pressed(keyboard, .RETURN);
            if h.smoke && h.frame == 560 nav.activate = true;
        }
        if blocked page.ctx.focused_id = 0;
        UI.ui_set_navigation(*page.ctx, nav); draw_page(i);
    }
    render_book();
}
