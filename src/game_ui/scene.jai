// Geometry and icon silhouettes ported from olib_sample/game_ui/scene.odin.
GOLD :: F.Color.{196, 167, 105, 255};
PAPER :: F.Color.{225, 218, 199, 255};
MUTED :: F.Color.{137, 148, 143, 255};
JADE :: F.Color.{94, 190, 167, 255};
line :: (a: F.Vector2, b: F.Vector2, width: float32, color: F.Color) { R.line(*h.renderer, a, b, width, color); }
ellipse :: (p: F.Vector2, rx: float32, ry: float32, color: F.Color, stroke: float32 = 0) {
    for i: 0..63 {
        a := cast(float32) i * TAU / 64; b := cast(float32) (i + 1) * TAU / 64;
        pa := p + F.Vector2.{cos(a) * rx, sin(a) * ry}; pb := p + F.Vector2.{cos(b) * rx, sin(b) * ry};
        if stroke > 0 line(pa, pb, stroke, color); else R.triangle(*h.renderer, p, pa, pb, color);
    }
}
stone :: (x: float32, y: float32, w: float32, d: float32, height: float32, color: F.Color) {
    a := F.Vector2.{x, y - d - height}; b := F.Vector2.{x + w, y - height};
    c := F.Vector2.{x, y + d - height}; e := F.Vector2.{x - w, y - height};
    R.quad(*h.renderer, e, c, .{x, y + d}, .{x - w, y}, .{25, 38, 40, 255});
    R.quad(*h.renderer, c, b, .{x + w, y}, .{x, y + d}, .{17, 29, 34, 255});
    R.quad(*h.renderer, a, b, c, e, color);
    line(e, c, 1, .{72, 90, 82, 255}); line(c, b, 1, .{54, 72, 69, 255});
}
pillar :: (x: float32, y: float32, height: float32) {
    ellipse(.{x + 36, y + 18}, 65, 19, .{4, 10, 14, 130});
    stone(x, y, 33, 18, 12, .{62, 79, 70, 255});
    stone(x, y - 10, 21, 12, height, .{73, 87, 73, 255});
    stone(x, y - height - 10, 30, 17, 12, .{81, 95, 78, 255});
    line(.{x - 11, y - 18}, .{x - 11, y - height + 2}, 2, .{55, 72, 64, 255});
    line(.{x + 9, y - 18}, .{x + 9, y - height + 2}, 2, .{9, 22, 25, 255});
}
torch :: (x: float32, y: float32) {
    R.circle_gradient(*h.renderer, .{x, y - 23}, 100, 40, .{34, 23, 6, 52}, .{0, 0, 0, 0});
    stone(x, y, 12, 7, 20, .{63, 58, 44, 255});
    R.triangle(*h.renderer, .{x - 9, y - 23}, .{x + 7, y - 23}, .{x + 2 + sin(elapsed * 4) * 3, y - 55}, .{222, 120, 40, 255});
    R.triangle(*h.renderer, .{x - 4, y - 23}, .{x + 4, y - 23}, .{x, y - 42}, .{255, 223, 128, 255});
}
actor :: (at: F.Vector2, enemy: bool) {
    x := at.x; y := at.y;
    ellipse(.{x, y + 5}, 20, 8, .{2, 8, 10, 155});
    cloak := ifx enemy then F.Color.{74, 87, 83, 255} else F.Color.{145, 60, 40, 255};
    R.triangle(*h.renderer, .{x, y - 37}, .{x - 18, y + 2}, .{x + 14, y + 4}, cloak);
    R.rect(*h.renderer, .{x - 6, y - 33, 13, 23}, .{109, 125, 119, 255});
    R.triangle(*h.renderer, .{x - 9, y - 34}, .{x + 1, y - 50}, .{x + 10, y - 34}, .{154, 164, 147, 255});
    R.rect(*h.renderer, .{x - 7, y - 35, 15, 5}, .{32, 42, 41, 255});
    line(.{x + 13, y - 13}, .{x + 29, y - 44}, 3, .{198, 208, 185, 255});
    line(.{x + 12, y - 24}, .{x + 24, y - 18}, 3, GOLD);
    line(.{x - 4, y - 7}, .{x - 7, y + 6}, 5, .{40, 42, 36, 255});
    line(.{x + 5, y - 7}, .{x + 7, y + 6}, 5, .{40, 42, 36, 255});
    if enemy { R.rect(*h.renderer, .{x - 22, y - 64, 44, 4}, .{29, 28, 26, 255}); R.rect(*h.renderer, .{x - 21, y - 63, 32, 2}, .{155, 65, 54, 255}); }
}
draw_world :: () {
    R.rect_gradient(*h.renderer, .{0, 0, 1280, 800}, .{10, 23, 28, 255}, .{16, 32, 34, 255}, .{9, 17, 23, 255}, .{6, 15, 22, 255});
    for i: 0..13 stone(cast(float32) i * 98 - 20, 190 + cast(float32) ((i * 37) % 6) * 12, 56, 25, 80 + cast(float32) ((i * 19) % 70), .{28, 48, 46, 255});
    for row: 0..11 for col: 0..11 {
        x := 580 + cast(float32) (col - row) * 52; y := 155 + cast(float32) (col + row) * 25;
        v := cast(u8) ((col * 17 + row * 11) % 12);
        stone(x, y, 51, 24, 12, .{33 + v, 49 + v, 47 + v, 255});
        if (col * 3 + row * 7) % 11 == 0 line(.{x - 15, y - 14}, .{x + 19, y - 9}, 1, .{18, 32, 33, 255});
    }
    ellipse(.{571, 413}, 164, 78, .{23, 45, 43, 255});
    ellipse(.{571, 413}, 166, 80, .{73, 99, 83, 255}, 3);
    ellipse(.{571, 413}, 145, 69, .{90, 124, 99, 255}, 1);
    ellipse(.{571, 413}, 103, 49, .{50, 106, 89, 255}, 2);
    for i: 0..11 {
        a := cast(float32) i * TAU / 12; p := F.Vector2.{571 + cos(a) * 126, 413 + sin(a) * 60};
        line(p + F.Vector2.{-3, -5}, p + F.Vector2.{3, 4}, 2, .{77, 135, 104, 255});
    }
    pillar(345, 322, 116); pillar(583, 219, 145); pillar(819, 328, 108);
    stone(770, 486, 30, 16, 38, .{57, 73, 63, 255}); stone(802, 504, 24, 13, 15, .{65, 77, 63, 255});
    torch(362, 337); torch(804, 346);
    R.quad(*h.renderer, .{557, 207}, .{583, 172}, .{609, 207}, .{583, 239}, .{56, 137, 111, 255});
    R.quad(*h.renderer, .{569, 207}, .{583, 186}, .{597, 207}, .{583, 226}, .{162, 222, 179, 255});
    actor(.{414, 391}, true); actor(.{721, 425}, true);
    ellipse(player + F.Vector2.{0, 5}, 26, 12, GOLD, 2); actor(player, false);
    if abs(destination.x - player.x) + abs(destination.y - player.y) > 5 ellipse(destination, 13, 6, GOLD, 1);
    if effect_timer > 0 ellipse(player, 40 + (0.8 - effect_timer) * 180, 20 + (0.8 - effect_timer) * 80, .{90, 170, 125, 200}, 3);
    for i: 0..79 {
        x := cast(float32) ((i * 137 + 31) % 1100) + 80; y := cast(float32) ((i * 89) % 390) + 270;
        if i % 3 == 0 line(.{x, y}, .{x - 3, y - 9}, 2, .{49, 71, 48, 255});
        else R.rect(*h.renderer, .{x, y, 3, 2}, .{55, 68, 58, 255});
    }
    for i: 0..29 R.rect(*h.renderer, .{270 + cast(float32) ((i * 131) % 600), 170 + cast(float32) ((i * 79) % 380) - sin(elapsed + cast(float32) i) * 6, 2, 2}, .{110, 137, 84, 160});
    R.rect_gradient(*h.renderer, .{0, 610, 1280, 190}, .{0, 0, 0, 0}, .{0, 0, 0, 0}, .{5, 10, 14, 248}, .{5, 10, 14, 248});
}
icon_sub :: (index: int) -> F.Subtexture { return F.subtexture_make_source(icons, .{cast(float32) (index % 8) * 64, 0, 64, 64}); }
make_icons :: () {
    img := F.image_create(512, 64); defer F.image_destroy(*img);
    colors: [8] F.Color = .[.{204,207,181,255}, .{128,171,182,255}, .{222,153,71,255}, .{137,175,210,255}, .{193,86,70,255}, .{111,185,146,255}, .{186,163,113,255}, .{100,137,118,255}];
    for n: 0..7 for y: 0..63 for x: 0..63 {
        xf := cast(float32) x - 32; yf := cast(float32) y - 32; inside := false;
        if n == 0 inside = (abs(xf + yf) < 5 && xf - yf > -10 && xf - yf < 45) || (abs(xf - yf + 10) < 3 && abs(xf + yf) < 15) || (abs(xf + yf) < 3 && xf - yf > -32 && xf - yf < -12);
        if n == 1 inside = abs(xf) < 20 && yf > -21 && yf < 23 - abs(xf) * 0.75;
        if n == 2 inside = abs(xf + sin(yf * 0.1) * 5) < (yf + 27) * 0.4 && yf > -27 && yf < 19;
        if n == 3 inside = abs(xf) * 1.4 + abs(yf) < 27;
        if n == 4 inside = xf * xf + (yf - 7) * (yf - 7) < 260 || (abs(xf) < 7 && yf > -23 && yf < 4);
        if n == 5 inside = abs(xf + yf * 0.6) < 10 && yf > -23 && yf < 20 && ((cast(int) (yf + 50)) % 7 < 5 || abs(xf + yf * 0.6) < 2);
        if n == 6 inside = abs(xf) < 18 && yf > -23 + abs(xf) * 0.4 && yf < 23 && !(yf > -4 && yf < 2 && abs(xf) > 3);
        if n == 7 inside = (abs(xf) < 2 && abs(yf) < 25) || (abs(yf) < 2 && abs(xf) < 25) || (abs(abs(xf) - 20) < 2 && abs(yf) < 9) || (abs(abs(yf) - 20) < 2 && abs(xf) < 9);
        if inside {
            color := colors[n]; if xf > 1 { color.r = cast(u8) (cast(float32) color.r * 0.65); color.g = cast(u8) (cast(float32) color.g * 0.65); color.b = cast(u8) (cast(float32) color.b * 0.65); }
            F.image_set_pixel(*img, cast(s32) (n * 64 + x), cast(s32) y, color);
        }
    }
    icons = F.texture_create_from_colors(F.App.device, 512, 64, img.Data);
}
