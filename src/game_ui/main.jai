#load "../../shared/ui_sample.jai";
#load "scene.jai";
#load "hud.jai";

paused, settings: bool;
bag_open: bool = true;
music: bool = true;
volume: float32 = 0.65;
selected: int = 3;
health: float32 = 0.78;
energy: float32 = 0.64;
elapsed, effect_timer: float32;
cooldowns: [6] float32 = .[0, 0, 0, 3.8, 0, 0];
cooldown_lengths: [6] float32 = .[1.2, 3, 5, 8, 4, 6];
player: F.Vector2 = .{564, 422};
destination: F.Vector2 = .{564, 422};
notice: string = "A forgotten oath still echoes here.";
icons, button_skin: *F.Texture;
world_scale: float32;

main :: () { sample_run("game_ui", 1280, 800); }
sample_start :: () {
    paused = has_arg("modal"); bag_open = !has_arg("hud");
    h.theme.panel = .{20, 29, 33, 248}; h.theme.accent = GOLD;
    h.theme.text = PAPER; h.theme.text_dim = MUTED; h.theme.padding = 8;
    h.theme.primary = .{137, 106, 57, 255}; h.theme.corner_radius = 12;
    make_icons();
    image := F.image_decode(cast([] u8) BUTTON_SKIN); defer F.image_destroy(*image);
    assert(image.Width > 0); F.image_premultiply(*image);
    button_skin = F.texture_create_from_colors(F.App.device, image.Width, image.Height, image.Data);
}
BUTTON_SKIN :: #run embed_file(tprint("%/assets/button-skin.png", #filepath));
sample_stop :: () {
    for texture: *F.Texture.[icons, button_skin] { F.texture_dispose(texture); free(texture); }
}
sample_update :: () {
    if !h.smoke && F.keyboard_pressed(F.input_keyboard(F.App.input), .ESCAPE) { paused = !paused; settings = false; }
    UI.ui_set_modal(*h.ui, ifx paused then "pause" else "");
    if paused return;
    elapsed += h.dt; effect_timer = max(effect_timer - h.dt, 0);
    for *cooldown: cooldowns cooldown.* = max(cooldown.* - h.dt, 0);
    delta := destination - player;
    distance := sqrt(delta.x * delta.x + delta.y * delta.y);
    if distance > 2 player += delta * (min(distance, h.dt * 135) / distance);
}
activate_skill :: (index: int) {
    if paused || cooldowns[index] > 0 return;
    cooldowns[index] = cooldown_lengths[index]; effect_timer = 0.8;
    if index == 4 { health = min(health + 0.18, 1); notice = "Ember flask restored your vitality."; }
    else { energy = max(energy - 0.035, 0.12); notice = skill_names[index]; }
}
sample_draw :: () {
    world_scale = min(h.ui.width / 1280, h.ui.height / 800);
    R.push_matrix_trs(*h.renderer, .{(h.ui.width - 1280 * world_scale) * h.scale * 0.5, 0},
        .{world_scale * h.scale, world_scale * h.scale}, 0, false);
    draw_world(); R.pop_matrix(*h.renderer);
    declare_hud();
}
sample_after_ui :: () {
    if paused || h.smoke return;
    captured := UI.ui_input_capture(*h.ui);
    kb := F.input_keyboard(F.App.input);
    if !captured.keyboard {
        if F.keyboard_pressed(kb, .B) bag_open = !bag_open;
        keys: [6] F.Keys = .[.NUM_1, .NUM_2, .NUM_3, .NUM_4, .NUM_5, .NUM_6];
        for key, i: keys if F.keyboard_pressed(kb, key) activate_skill(i);
    }
    if !captured.pointer && h.pressed {
        destination = .{clamp((h.pointer.x - (h.ui.width - 1280 * world_scale) * 0.5) / world_scale, 250, 840),
                         clamp(h.pointer.y / world_scale, 265, 600)};
    }
}
sample_test_input :: () {
    f := h.frame;
    if f == 1 || f == 2 test_click("skill-0", f == 1);
    if f == 3 || f == 4 test_click("item-2", f == 3);
    if f == 5 || f == 6 test_click("pause-open", f == 5);
    if f == 8 || f == 9 test_click("settings", f == 8);
    if f == 11 || f == 12 test_click("volume", f == 11, 0.92);
    if f == 13 || f == 14 test_click("music", f == 13);
    if f == 15 || f == 16 test_click("settings-back", f == 15);
    if f == 18 || f == 19 test_click("resume", f == 18);
}
sample_test_check :: () {
    f := h.frame;
    if f == 3 assert(cooldowns[0] > 0, "skill cooldown");
    if f == 5 assert(selected == 2, "inventory selection");
    if f == 7 assert(paused, "pause");
    if f == 10 assert(settings, "settings");
    if f == 13 assert(volume > 0.85, "slider");
    if f == 15 assert(!music, "music toggle");
    if f == 17 assert(!settings, "back");
    if f == 22 { assert(!paused, "resume"); h.done = true; }
}

