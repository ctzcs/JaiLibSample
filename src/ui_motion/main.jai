#load "../../shared/ui_sample.jai";
TW :: #import "core/tween";
#load "cards.jai";
#load "view.jai";

main :: () { sample_run("ui_motion", 1200, 760); }
sample_start :: () {
    h.theme.text = PAPER; h.theme.text_dim = MUTED; h.theme.accent = GOLD;
    h.theme.button = .{147, 53, 43, 255}; h.theme.button_hover = .{175, 70, 53, 255};
    h.theme.body_font_size = 18; h.theme.padding = 12;
    tweens = TW.manager_make();
    for *card, i: cards { card.motion = UI.UI_VISUAL_DEFAULT; hand[i] = i; hand_open[i] = 1; }
    for *slot: slots slot.* = -1;
    make_icons();
}
sample_stop :: () { TW.manager_delete(*tweens); F.texture_dispose(icons); free(icons); }
sample_update :: () {
    TW.manager_update(*tweens, h.dt);
    if !h.smoke && F.keyboard_pressed(F.input_keyboard(F.App.input), .ESCAPE) {
        if drag >= 0 { cards[drag].flying = true; drag = -1; h.ui.active_id = 0; }
        else if modal_open modal_open = false;
        else F.app_exit();
    }
    if playing {
        play_timer -= h.dt;
        if play_timer <= 0 {
            fired := false;
            while play_slot < 3 {
                index := slots[play_slot]; play_slot += 1;
                if index >= 0 {
                    animate(index, ifx index == 1 then 1 else 0);
                    if index == 0 attacks += 1;
                    if index == 1 rewards += 1;
                    if index == 2 gate_opened = true;
                    if index == 3 { guards += 1; UI.ui_motion_kick(*h.ui, "pop-3", .{scale = .{6, 6}, rotation = -2.4}); }
                    play_timer = 0.42; fired = true; break;
                }
            }
            if !fired {
                playing = false;
                for i: 0..3 if cards[i].queued return_home(i);
                if gate_opened modal_open = true;
            }
        }
    }
    UI.ui_set_modal(*h.ui, ifx modal_open then "reward-modal" else "");
}
sample_after_ui :: () {}
sample_test_input :: () {
    f := h.frame;
    if f == 3 test_click("card-0", true);
    if f == 4 || f == 5 test_pointer(rect_center(slot_rects[0]), f == 4);
    if f == 30 test_click("card-1", true);
    if f == 31 || f == 32 test_pointer(rect_center(slot_rects[0]), f == 31);
    if f == 60 || f == 61 test_click("card-2", f == 60);
    if f == 90 test_click("card-3", true);
    if f == 91 || f == 92 test_pointer(.{tray.x - 5, tray.y + tray.h * 0.5}, f == 91);
    if f == 125 || f == 126 test_click("execute", f == 125);
    if f == 200 || f == 201 test_click("continue", f == 200);
    if f == 220 { F.window_set_size(F.App.window, .{760, 800}); h.scale = 1.25; }
    if f == 250 UI.ui_focus(*h.ui, "card-3");
    if f == 251 UI.ui_set_navigation(*h.ui, .{activate = true});
}
sample_test_check :: () {
    if h.frame == 6 assert(slots[0] == 0, "drag into action slot");
    if h.frame == 33 assert(slots[0] == 1 && !cards[0].queued, "swap occupied slot");
    if h.frame == 62 assert(slots[1] == 2, "click queues gate");
    if h.frame == 93 assert(hand[0] == 3, "reorder hand by drag");
    if h.frame == 190 assert(modal_open && rewards == 1 && !playing, "queue executes and gate opens modal");
    if h.frame == 205 assert(!modal_open, "dismiss reward");
    if h.frame == 275 {
        assert(cards[3].queued, "keyboard queues guard after resize");
        for i: 0..3 assert(cards[i].pos.x >= 0 && cards[i].pos.x + card_size.x <= h.ui.width + 1, "card within viewport");
        h.done = true;
    }
}
