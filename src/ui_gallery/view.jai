QUALITIES: [4] string = .["Low", "Medium", "High", "Ultra"];
COMPONENTS: [12] string = .["Button", "Toggle", "Slider", "Text input", "Dropdown", "Progress bar",
    "Scroll view", "Modal dialog", "Keyboard focus", "MSDF text", "Rounded panel", "Clipped list"];

draw_gallery :: () {
    root := UI.ui_column_decl(20);
    root.layout.padding = clay.PaddingAll(28);
    root.layout.sizing.height = clay.SizingGrow();
    clay.UI(root, #code {
        UI.ui_label_ex(*g.ui, *g.theme, "J A I L I B   /   S A M P L E   0 1", g.theme.accent, 13);
        UI.ui_heading(*g.ui, *g.theme, "Interface playground");
        UI.ui_label_dim(*g.ui, *g.theme, "A pure UI sample powered by JaiLib, Clay and jfoster.");
        UI.ui_separator(*g.ui, *g.theme);
        // Stack panels on small logical viewports. The outer scroller keeps every control reachable.
        page := UI.ui_scroll_decl(*g.ui, "page-scroll", 300, gap = 18);
        page.layout.sizing.height = clay.SizingGrow();
        clay.UI(page, #code {
            body := UI.ui_row_decl(20);
            if g.ui.width < 850 body = UI.ui_column_decl(20);
            body.layout.childAlignment.y = .TOP;
            clay.UI(body, #code {
                draw_settings();
                draw_components();
            });
        });
        UI.ui_label_dim(*g.ui, *g.theme, g.status);
        UI.ui_label_dim(*g.ui, *g.theme, "Tab / Shift+Tab: focus   Enter: activate   Arrows: adjust   Esc: close");
    });
    if g.dialog draw_dialog();
}

draw_settings :: () {
    panel := UI.ui_panel_decl(*g.theme, 12);
    panel.id = clay.ID("settings-panel");
    if g.ui.width >= 850 panel.layout.sizing.width = clay.SizingFixed(350);
    clay.UI(panel, #code {
        UI.ui_label_dim(*g.ui, *g.theme, "01 / PREFERENCES");
        UI.ui_heading(*g.ui, *g.theme, "Make it yours");
        UI.ui_label(*g.ui, *g.theme, "Display name");
        UI.ui_text_input(*g.ui, *g.theme, "name", *g.name, "Your name", 280, 64);
        clay.UI(UI.ui_row_decl(), #code {
            UI.ui_label(*g.ui, *g.theme, "Music enabled");
            UI.ui_spacer();
            UI.ui_toggle(*g.ui, *g.theme, "music", *g.music);
        });
        UI.ui_label(*g.ui, *g.theme, tprint("Volume   %%", cast(int) (g.volume * 100), "%"));
        UI.ui_slider(*g.ui, *g.theme, "volume", *g.volume, width = 280);
        UI.ui_label(*g.ui, *g.theme, "Quality preset");
        UI.ui_dropdown(*g.ui, *g.theme, "quality", QUALITIES, *g.quality, 280);
        UI.ui_separator(*g.ui, *g.theme);
        UI.ui_label_dim(*g.ui, *g.theme, "LIVE LEVEL");
        UI.ui_progress_bar(*g.ui, *g.theme, g.volume, 280);
        clay.UI(UI.ui_row_decl(10), #code {
            if UI.ui_button_ex(*g.ui, *g.theme, "apply", "Apply settings", .Primary) {
                g.applied += 1;
                g.status = "Settings applied to this session.";
            }
            if UI.ui_button(*g.ui, *g.theme, "reset", "Reset...") g.dialog = true;
        });
        UI.ui_button(*g.ui, *g.theme, "locked", "Unavailable action", .{disabled = true});
    });
}

draw_components :: () {
    panel := UI.ui_panel_decl(*g.theme, 14);
    panel.id = clay.ID("components-panel");
    clay.UI(panel, #code {
        UI.ui_label_dim(*g.ui, *g.theme, "02 / COMPONENT LIBRARY");
        UI.ui_heading(*g.ui, *g.theme, "Built to interact");
        UI.ui_label_dim(*g.ui, *g.theme, "24 entries / clipped scrolling / persistent selection");
        clay.UI(UI.ui_scroll_decl(*g.ui, "component-scroll", 290, gap = 6), #code {
            for i: 0..23 {
                row := UI.ui_row_decl(12);
                row.layout.padding = clay.PaddingAll(8);
                row.backgroundColor = UI.ui_clay_color(ifx g.selected == i then g.theme.button_hover else g.theme.window_bg);
                row.cornerRadius = clay.CornerRadiusAll(6);
                clay.UI(row, #code {
                    UI.ui_label_ex(*g.ui, *g.theme, tprint("%", i + 1), g.theme.accent, 16);
                    UI.ui_label(*g.ui, *g.theme, COMPONENTS[i % COMPONENTS.count]);
                    UI.ui_spacer();
                    if UI.ui_button_ex(*g.ui, *g.theme, tprint("item-%", i),
                        ifx g.selected == i then "Selected" else "Inspect", .Ghost) g.selected = i;
                });
            }
        });
        UI.ui_separator(*g.ui, *g.theme);
        if g.selected < 0 UI.ui_label(*g.ui, *g.theme, "Select a component to inspect it.");
        else UI.ui_label(*g.ui, *g.theme, tprint("Selected: % / %", g.selected + 1, COMPONENTS[g.selected % COMPONENTS.count]));
        UI.ui_label_dim(*g.ui, *g.theme, "Rendered through kit/ui + kit/rendering/2d.");
    });
}

draw_dialog :: () {
    UI.ui_set_scope(*g.ui, "confirm-dialog");
    defer UI.ui_set_scope(*g.ui, "");
    clay.UI(UI.ui_modal_decl(*g.ui, "confirm-dialog"), #code {
        clay.UI(UI.ui_panel_decl(*g.theme, 18, min(g.ui.width - 40, 420)), #code {
            UI.ui_label_dim(*g.ui, *g.theme, "RESET PREFERENCES");
            UI.ui_heading(*g.ui, *g.theme, "Start fresh?");
            UI.ui_label(*g.ui, *g.theme, "Restore music, volume and quality to their defaults? Your display name stays the same.");
            clay.UI(UI.ui_row_decl(12), #code {
                if UI.ui_button(*g.ui, *g.theme, "cancel", "Keep settings") g.dialog = false;
                if UI.ui_button_ex(*g.ui, *g.theme, "confirm", "Reset settings", .Primary) {
                    g.music = true;
                    g.volume = 0.65;
                    g.quality = 1;
                    g.dialog = false;
                    g.status = "Preferences restored to defaults.";
                }
            });
        });
    });
}
