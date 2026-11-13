PAPER :: F.Color.{237, 222, 191, 255};
MUTED :: F.Color.{163, 156, 139, 255};
GOLD :: F.Color.{219, 175, 89, 255};
icons: *F.Texture;

sample_draw :: () {
    layout_cards(); root_element();
    C.UI(anchor("header", 28, 24, h.ui.width - 56), #code {
        label("MOTION STUDY / 02", 14, GOLD);
        label("Drag. Drop. Strike.", ifx h.ui.width < 700 then 27 else 36, PAPER);
        label("Drag cards into the action slots, then press GO.", 15, MUTED);
    });
    for r, i: slot_rects {
        id := tprint("slot-%", i); visual := UI.UI_VISUAL_DEFAULT;
        if hover_slot == i visual.scale = .{1.06, 1.06};
        UI.ui_motion(*h.ui, id, visual, .{time = 0.22, bounce = 0.35});
        d := anchor(id, r.x, r.y, r.w, r.h);
        d.backgroundColor = UI.ui_clay_color(ifx hover_slot == i then GOLD else F.Color.{95, 87, 72, 255});
        d.cornerRadius = C.CornerRadiusAll(12); d.layout.padding = C.PaddingAll(2);
        C.UI(d, #code {
            inner := UI.ui_column_decl(8); inner.layout.sizing = .{width = C.SizingGrow(), height = C.SizingGrow()};
            inner.layout.childAlignment = .{x = .CENTER, y = .CENTER}; inner.backgroundColor = .[0.12, 0.13, 0.14, 1];
            inner.cornerRadius = C.CornerRadiusAll(10);
            C.UI(inner, #code { label(tprint("%", i + 1), 16, MUTED); label("+", 40, GOLD); });
        });
    }
    C.UI(anchor("go", slot_rects[2].x + slot_rects[2].w + 20, 220, 90), #code {
        queued := false; for occupant: slots if occupant >= 0 queued = true;
        if UI.ui_button(*h.ui, *h.theme, "execute", ifx playing then "..." else "GO", .{disabled = playing || !queued}) execute();
    });
    d := anchor("tray", tray.x, tray.y, tray.w, tray.h, 5);
    d.backgroundColor = .[0.44, 0.28, 0.18, 1]; d.cornerRadius = C.CornerRadiusAll(16); C.UI(d);
    C.UI(anchor("footer", 28, h.ui.height - 78, h.ui.width - 56), #code {
        label(tprint("ATTACKS % / RELICS % / GUARDS %", attacks, rewards, guards), 16, GOLD);
        label("Tab select / Enter queue / Esc cancel", 14, MUTED);
    });
    for i: 0..3 draw_card(i);
    alive, t := UI.ui_presence(*h.ui, "reward-modal", modal_open, .{time = 0.4, bounce = 0.25}, .{time = 0.15});
    if alive {
        UI.ui_set_scope(*h.ui, "reward-modal");
        C.UI(UI.ui_modal_decl(*h.ui, "reward-modal"), #code {
            hidden := UI.UI_VISUAL_DEFAULT; hidden.offset.y = 90; hidden.scale = .{0.85, 0.85}; hidden.opacity = 0;
            UI.ui_set_visual(*h.ui, "reward-panel", UI.ui_visual_lerp(hidden, UI.UI_VISUAL_DEFAULT, t));
            panel := UI.ui_panel_decl(*h.theme, 18, min(h.ui.width - 60, 440)); panel.id = C.ID("reward-panel");
            panel.layout.childAlignment.x = .CENTER;
            C.UI(panel, #code {
                label("A MOMENT OF VICTORY", 18, GOLD);
                UI.ui_image(*h.ui, F.subtexture_make_source(icons, .{96, 0, 96, 96}), 96, 96);
                label("A new power awaits", 26, PAPER);
                label("Ready for the next encounter.", 16, MUTED);
                if UI.ui_button(*h.ui, *h.theme, "continue", "CONTINUE") modal_open = false;
            });
        });
        UI.ui_set_scope(*h.ui, "");
    }
}
draw_card :: (index: int) {
    id := tprint("card-%", index); state := UI.ui_interact(*h.ui, id, .{disabled = playing});
    if state.pressed && drag < 0 {
        drag = index; drag_grab = h.pointer - cards[index].pos; drag_start = h.pointer; drag_moved = false;
    }
    if drag == index {
        if state.active { if length2(h.pointer - drag_start) > 5 drag_moved = true; }
        else drop_card(index);
    } else if state.clicked toggle(index);
    step_card(index, state.hovered && !playing);
    c := *cards[index]; k := card_size.x / 124;
    z: s16 = cast(s16) ifx drag == index then 40 else (ifx c.flying then 30 else 20);
    visual := c.motion; visual.offset.y -= c.lift * 12; visual.rotation += c.tilt;
    UI.ui_set_visual(*h.ui, id, visual);
    shadow := visual; shadow.offset += .{4 + 8 * c.lift, 6 + 14 * c.lift};
    sid := tprint("shadow-%", index); UI.ui_set_visual(*h.ui, sid, shadow);
    d := anchor(sid, c.pos.x, c.pos.y, card_size.x, card_size.y, z - 1);
    d.floating.pointerCaptureMode = .PASSTHROUGH; d.backgroundColor = .[0, 0, 0, 0.4]; d.cornerRadius = C.CornerRadiusAll(12 * k); C.UI(d);
    names: [4] string = .["ATTACK", "RELIC", "GATE", "GUARD"];
    verbs: [4] string = .["STRIKE", "COLLECT", "OPEN", "PROTECT"];
    colors: [4] F.Color = .[.{147, 53, 43, 255}, .{44, 78, 70, 255}, .{70, 58, 44, 255}, .{50, 60, 76, 255}];
    d = anchor(id, c.pos.x, c.pos.y, card_size.x, card_size.y, z);
    d.backgroundColor = UI.ui_clay_color(ifx state.focused || drag == index then GOLD else PAPER);
    d.cornerRadius = C.CornerRadiusAll(12 * k); d.layout.padding = C.PaddingAll(2);
    pop := tprint("pop-%", index); UI.ui_motion(*h.ui, pop, UI.UI_VISUAL_DEFAULT, .{time = 0.3, bounce = 0.45});
    C.UI(d, #code {
        inner := UI.ui_column_decl(2); inner.id = C.ID(pop);
        inner.layout.sizing = .{width = C.SizingGrow(), height = C.SizingGrow()};
        inner.layout.childAlignment = .{x = .CENTER, y = .CENTER};
        inner.backgroundColor = UI.ui_clay_color(colors[index]); inner.cornerRadius = C.CornerRadiusAll(10 * k);
        C.UI(inner, #code {
            label(names[index], cast(u16) max(14 * k, 11), GOLD);
            UI.ui_image(*h.ui, F.subtexture_make_source(icons, .{cast(float32) index * 96, 0, 96, 96}), 78 * k, 78 * k);
            label(ifx index == 0 then "2" else (ifx index == 2 then "3" else "1"), cast(u16) (28 * k), PAPER);
            label(verbs[index], cast(u16) max(14 * k, 11), PAPER);
        });
    });
}
make_icons :: () {
    img := F.image_create(384, 96); defer F.image_destroy(*img);
    for y: 0..95 for x: 0..383 {
        kind := x / 96; px := x / 3 % 32; py := y / 3; color: F.Color;
        if kind == 0 {
            if px >= 9 && px <= 24 && abs(31 - py - px) <= 1 color = PAPER;
            if (px >= 6 && px <= 13 && abs(py - px - 12) <= 1) || (px >= 4 && px <= 9 && abs(31 - py - px) <= 1) color = GOLD;
        }
        if kind == 1 {
            if abs(px - 16) * 2 + abs(py - 15) <= 14 color = ifx px <= 15 then F.Color.{135, 189, 164, 255} else F.Color.{67, 121, 113, 255};
            if py == 28 && px >= 9 && px <= 23 color = GOLD;
        }
        if kind == 2 && (((px == 10 || px == 11 || px == 21 || px == 22) && py >= 10 && py <= 27) || (py >= 7 && py <= 9 && px >= 5 && px <= 27) || (py == 14 && px >= 8 && px <= 24)) color = GOLD;
        half := ifx py <= 17 then 11 else 28 - py;
        if kind == 3 && py >= 5 && half >= 0 && abs(px - 16) <= half {
            color = ifx abs(px - 16) >= half - 1 || py <= 6 then PAPER else F.Color.{78, 94, 122, 255};
            if px == 16 color = GOLD;
        }
        img.Data[y * 384 + x] = color;
    }
    icons = F.texture_create_from_colors(F.App.device, img.Width, img.Height, img.Data);
}



