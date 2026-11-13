// Project actual page widgets into screen space, then exercise the ray -> UV -> UI path.
page_click :: (index: int, id: string, down: bool, fraction: float32 = 0.5) {
    box, found := UI.ui_element_rect(*pages[index].ctx, id); assert(found, "Missing page widget: %", id);
    x := box.x + box.w * fraction; y := box.y + box.h * 0.5;
    local := F.Vector3.{ifx index % 2 == 0 then x - PAGE_W else x, PAGE_H * 0.5 - y, 0};
    update_view(); test_pointer(project(local) / h.scale, down);
}
pause_progress: float32;
sample_test_input :: () {
    f := h.frame;
    assert(abs(turn_seconds - 0.95) < 0.001, "unrelated input changed turn duration at frame %: %", f, turn_seconds);
    if f == 3 || f == 4 page_click(0, "bookmark", f == 3);
    if f == 6 || f == 7 page_click(1, "spell-1", f == 6);
    if f == 9 || f == 10 page_click(1, "cast", f == 9);
    if f == 12 || f == 13 test_click("next", f == 12);
    if f == 20 || f == 21 test_click("pause", f == 20);
    if f == 23 pause_progress = progress;
    if f == 30 || f == 31 test_click("pause", f == 30);
    if f == 100 || f == 101 page_click(2, "potion", f == 100);
    if f == 104 || f == 105 page_click(3, "music", f == 104);
    if f == 108 || f == 109 page_click(3, "volume", f == 108, 0.9);
    if f == 115 || f == 116 test_click("next", f == 115);
    if f == 180 || f == 181 page_click(4, "bookmark-map", f == 180);
    if f == 184 || f == 185 page_click(5, "quest", f == 184);
    if f == 190 begin_turn(1); // Last-spread boundary must reject.
    if f == 195 || f == 196 test_click("previous", f == 195);
    if f == 265 || f == 266 test_click("previous", f == 265);
    if f == 335 {
        pose.rotation = quat_mul(quat_axis(.{0,1,0}, 0.38), pose.rotation); pose.position.x = 75; pose.position.z = 260;
    }
    if f == 340 || f == 341 page_click(1, "cast", f == 340);
    if f == 350 { pose.rotation = quat_axis(.{0,1,0}, PI); }
    if f == 355 || f == 356 page_click(1, "cast", f == 355);
    if f == 370 { reset_pose(); F.window_set_size(F.App.window, .{760,800}); h.scale = 1.25; }
    if f == 400 || f == 401 page_click(0, "bookmark", f == 400);
    if f == 550 { focus_page = 1; UI.ui_focus(*pages[1].ctx, "cast"); }
}
sample_test_check :: () {
    f := h.frame;
    if f == 11 {
        assert(bookmarked && selected_spell == 1 && casts == 1, "page ray interaction");
        verify_page_pixels();
    }
    if f == 28 assert(paused && progress == pause_progress, "turn pause");
    if f == 110 assert(spread == 1 && potions == 1 && !music && volume > 0.85, "second spread controls");
    if f == 191 assert(spread == 2 && direction == 0 && route_marked && quest_accepted, "third spread and boundary");
    if f == 330 assert(spread == 0 && bookmarked && casts == 1 && potions == 1 && route_marked, "reverse turn preserves state");
    if f == 342 assert(casts == 2, "transformed book picking");
    if f == 360 assert(casts == 2, "opaque cover blocks hidden page input");
    if f == 402 assert(!bookmarked, "picking after resize and scale");
    if f == 565 { assert(casts == 3, "keyboard page activation"); h.done = true; }
}
verify_page_pixels :: () {
    // Inspect the 3D target itself: a nonblank window alone would miss reversed
    // face winding that accidentally samples the white underside of both pages.
    img := F.image_create(book_target.Width, book_target.Height); defer F.image_destroy(*img);
    F.texture_get_data(F.target_texture(book_target), img.Data);
    paper := project(.{300, -210, 0});
    pixel := img.Data[cast(int) paper.y * img.Width + cast(int) paper.x];
    assert(pixel.r > 150 && pixel.g > 150 && cast(int) pixel.r - cast(int) pixel.b > 15, "3D page samples parchment texture");
    box, found := UI.ui_element_rect(*pages[1].ctx, "cast"); assert(found);
    button := project(.{box.x + 5, PAGE_H * 0.5 - box.y - box.h * 0.5, 0});
    pixel = img.Data[cast(int) button.y * img.Width + cast(int) button.x];
    assert(cast(int) pixel.g - cast(int) pixel.r > 20 && pixel.a > 200, "3D page samples its UI controls");
}
