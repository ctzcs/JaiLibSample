skill_names: [6] string = .["Riven blade", "Iron vow", "Ember burst", "Moonfall", "Ember flask", "Windstep"];
item_names: [6] string = .["WARDEN'S BLADE", "OATHBOUND SHIELD", "CINDER CORE", "MOONGLASS SHARD", "EMBER FLASK", "VERDANT PLUME"];
item_types: [6] string = .["WEAPON / +24 ATTACK", "ARMOR / +18 GUARD", "MATERIAL / FIRE", "RARE / ARCANE", "CONSUMABLE / RESTORE HP", "CHARM / +8 AGILITY"];

skin_decl :: (state: UI.UI_Interaction, important: bool = false) -> C.ElementDeclaration {
    tint := ifx important then F.Color.{255, 245, 218, 255} else F.Color.{180, 205, 212, 255};
    if state.disabled tint = .{90, 105, 112, 255};
    else if state.active tint = .{145, 158, 168, 255};
    else if state.hovered || state.focused tint = F.Color_White;
    return UI.ui_nine_slice_decl(*h.ui, button_skin, cast(float32) min(button_skin.Width, button_skin.Height) * 0.18, 11, tint);
}
panel_at :: (id: string, x: float32, y: float32, w: float32) -> C.ElementDeclaration {
    d := anchor(id, x, y, w); d.layout.padding = C.PaddingAll(16);
    d.backgroundColor = UI.ui_clay_color(h.theme.panel); d.cornerRadius = C.CornerRadiusAll(18);
    UI.ui_block_pointer(*h.ui, id); return d;
}
menu_button :: (id: string, title: string, important: bool = false) -> bool {
    state := UI.ui_interact(*h.ui, id); UI.ui_focus_style(*h.ui, *h.theme, state);
    d := skin_decl(state, important); d.id = C.ID(id);
    d.layout = .{sizing = .{width = C.SizingGrow(), height = C.SizingFixed(48)}, childAlignment = .{x = .CENTER, y = .CENTER}};
    C.UI(d, #code { label(title, 15, PAPER); }); return state.clicked;
}
meter :: (value: float32, width: float32, height: float32, color: F.Color) {
    theme := h.theme; theme.accent = color;
    UI.ui_progress_bar(*h.ui, *theme, value, width, height);
}
slot :: (id: string, icon: int, size: float32, chosen: bool, key: string = "", cooldown: float32 = 0, fraction: float32 = 0) -> bool {
    state := UI.ui_interact(*h.ui, id, .{disabled = icon < 0 || cooldown > 0});
    UI.ui_focus_style(*h.ui, *h.theme, state);
    d := skin_decl(state, chosen); d.id = C.ID(id);
    d.layout = .{sizing = .{width = C.SizingFixed(size), height = C.SizingFixed(size)}, childAlignment = .{x = .CENTER, y = .CENTER}};
    C.UI(d, #code {
        if icon >= 0 UI.ui_image(*h.ui, icon_sub(icon), size - 20, size - 20);
        if cooldown > 0 {
            C.UI(C.ElementDeclaration.{
                layout = .{sizing = .{width = C.SizingFixed(size - 6), height = C.SizingFixed((size - 6) * fraction)}},
                backgroundColor = .[0.015, 0.025, 0.03, 0.8],
                floating = .{attachTo = .PARENT, clipTo = .ATTACHED_PARENT, zIndex = 11, pointerCaptureMode = .PASSTHROUGH,
                    attachment = .{element = .CENTER_BOTTOM, parent = .CENTER_BOTTOM}},
            });
        }
        C.UI(C.ElementDeclaration.{floating = .{attachTo = .PARENT, clipTo = .ATTACHED_PARENT, zIndex = 12,
            pointerCaptureMode = .PASSTHROUGH, offset = .[5, 3]}}, #code {
            label(ifx cooldown > 0 then tprint("%", cast(int) ceil(cooldown)) else key, 12, PAPER);
        });
    }); return state.clicked;
}
declare_hud :: () {
    root_element();
    C.UI(anchor("vitals", 28, 26, 310), #code {
        label("THE WARDEN / LV. 12", 16, GOLD);
        meter(health, 238, 19, .{151, 56, 47, 255});
        meter(energy, 218, 12, .{55, 123, 140, 255});
        label(tprint("% / 1240 HP   % / 180 MP", cast(int) (health * 1240), cast(int) (energy * 180)), 11, PAPER);
    });
    if h.ui.width > 900 {
        C.UI(anchor("location", h.ui.width * 0.5 - 140, 28, 300), #code {
            label("A S H E N   V A L E", 22, PAPER); label("THE SUNKEN SANCTUM / DEPTH III", 11, GOLD);
        });
    }
    C.UI(anchor("quest", 30, 166, 230), #code {
        label("A LIGHT BENEATH", 14, GOLD); label("Find the sealed shrine", 17, PAPER);
        label("Collect the scattered sigils", 13, MUTED); label("II / III  SIGILS RECOVERED", 11, JADE);
    });
    C.UI(panel_at("map", h.ui.width - 158, 24, 130), #code {
        label("N / SANCTUM 03", 10, GOLD); UI.ui_image(*h.ui, icon_sub(7), 80, 80);
    });
    if bag_open {
        C.UI(panel_at("inventory", h.ui.width - 354, 182, 326), #code {
            C.UI(UI.ui_row_decl(), #code {
                label("SATCHEL", 24, PAPER); UI.ui_spacer();
                if UI.ui_button_ex(*h.ui, *h.theme, "bag-close", "X", .Ghost) bag_open = false;
            });
            label("18 / 24 SLOTS     23.4 / 40 KG", 11, MUTED);
            UI.ui_separator(*h.ui, *h.theme);
            C.UI(UI.ui_scroll_decl(*h.ui, "bag-scroll", max(min(h.ui.height - 520, 224), 80)), #code {
                for row: 0..5 C.UI(UI.ui_row_decl(8), #code {
                    for col: 0..3 {
                        i := row * 4 + col;
                        if slot(tprint("item-%", i), ifx i < 18 then i % 6 else -1, 62, selected == i,
                            ifx i < 18 && i % 3 == 0 then tprint("%", i + 2) else "") selected = i;
                    }
                });
            });
            UI.ui_separator(*h.ui, *h.theme);
            label(item_names[selected % 6], 16, GOLD); label(item_types[selected % 6], 11, MUTED);
            label("Recovered from the old sanctum.", 12, PAPER);
        });
    }
    C.UI(anchor("notice", h.ui.width * 0.5 - 205, h.ui.height - 154, 410), #code { label(notice, 13, GOLD); });
    C.UI(panel_at("hotbar", h.ui.width * 0.5 - 220, h.ui.height - 124, 440), #code {
        C.UI(UI.ui_row_decl(10), #code {
            for i: 0..5 if slot(tprint("skill-%", i), i, 58, i == 0, tprint("%", i + 1), cooldowns[i], cooldowns[i] / cooldown_lengths[i]) activate_skill(i);
        });
    });
    C.UI(anchor("controls", h.ui.width * 0.5 - 210, h.ui.height - 22, 440), #code {
        label("CLICK TO MOVE / 1-6 ABILITIES / B INVENTORY", 10, MUTED);
    });
    if h.ui.width > 900 C.UI(anchor("currency", 30, h.ui.height - 76, 190), #code { label("1,248 GOLD", 18, GOLD); });
    compact := h.ui.width < 900;
    C.UI(anchor("pause-button", ifx compact then 28.0 else h.ui.width - 168,
        ifx compact then h.ui.height - 216 else h.ui.height - 66, 140), #code {
        if menu_button("pause-open", "ESC / PAUSE") paused = true;
    });
    if h.ui.modal_id != 0 {
        UI.ui_set_scope(*h.ui, "pause");
        C.UI(UI.ui_modal_decl(*h.ui, "pause"), #code {
            C.UI(UI.ui_panel_decl(*h.theme, 14, 340), #code {
                label("A S H E N   V A L E", 21, GOLD);
                label(ifx settings then "SOUND & AMBIENCE" else "JOURNEY PAUSED", 12, MUTED);
                UI.ui_separator(*h.ui, *h.theme);
                if settings {
                    label("Master volume", 15, PAPER); UI.ui_slider(*h.ui, *h.theme, "volume", *volume, width = 280);
                    label("Ambient music", 15, PAPER); UI.ui_toggle(*h.ui, *h.theme, "music", *music);
                    if menu_button("settings-back", "BACK") settings = false;
                } else {
                    label("The ruins can wait a little longer.", 13, PAPER);
                    if menu_button("resume", "CONTINUE JOURNEY", true) paused = false;
                    if menu_button("settings", "SOUND & AMBIENCE") settings = true;
                    if menu_button("quit", "LEAVE THE RUINS") F.app_exit();
                }
            });
        });
        UI.ui_set_scope(*h.ui, "");
    }
}
