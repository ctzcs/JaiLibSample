Page :: struct { ctx: UI.UI_Context; target: *F.Target; renderer: R.Render2D; }
pages: [6] Page;
paper_theme: UI.UI_Theme;
PAPER :: F.Color.{240,231,202,255};
bookmarked, route_marked, quest_accepted: bool;
selected_spell, casts, potions: int;
music: bool = true;
volume: float32 = 0.65;
pages_start :: () {
    paper_theme = h.theme;
    paper_theme.text = .{48,55,46,255}; paper_theme.text_dim = .{116,115,93,255};
    paper_theme.panel = .{226,216,186,255}; paper_theme.panel_border = .{180,165,127,255};
    paper_theme.button = .{213,204,174,255}; paper_theme.button_hover = .{196,191,157,255}; paper_theme.button_press = .{184,181,149,255};
    paper_theme.primary = .{47,103,88,255}; paper_theme.primary_hover = .{57,122,102,255}; paper_theme.primary_press = .{39,85,74,255};
    paper_theme.accent = paper_theme.primary; paper_theme.text_on_accent = .{245,239,214,255};
    paper_theme.body_font_size = 16; paper_theme.heading_font_size = 28; paper_theme.small_font_size = 12; paper_theme.padding = 10; paper_theme.corner_radius = 3;
    for *page: pages {
        assert(UI.ui_init(*page.ctx, PAGE_W, PAGE_H));
        UI.ui_register_font(*page.ctx, *h.font, h.font_texture, .MSDF);
        page.target = F.target_create(F.App.device, PAGE_W, PAGE_H);
        assert(R.init(*page.renderer, *h.materials) == "");
    }
}
pages_stop :: () {
    for *page: pages { UI.ui_dispose(*page.ctx); R.dispose(*page.renderer); F.target_dispose(page.target); free(page.target); }
}
illustration :: (height: float32) {
    d := UI.ui_column_decl(); d.id = C.ID("illustration"); d.layout.sizing.height = C.SizingFixed(height); C.UI(d);
}
draw_page :: (index: int) {
    page := *pages[index]; ctx := *page.ctx; theme := *paper_theme;
    R.reset(*page.renderer); UI.ui_begin(ctx, h.dt);
    root := UI.ui_column_decl(12); root.id = C.ID("paper");
    root.layout.sizing = .{width = C.SizingFixed(PAGE_W), height = C.SizingFixed(PAGE_H)};
    root.layout.padding = .{left = 30, right = 30, top = 26, bottom = 22};
    C.UI(root, #code {
        C.UI(UI.ui_row_decl(8), #code {
            UI.ui_label_dim(ctx, theme, "THE FIELD GRIMOIRE"); UI.ui_spacer(); UI.ui_label_dim(ctx, theme, tprint("0%", index + 1));
        });
        UI.ui_separator(ctx, theme);
        if index == 0 {
            UI.ui_label_dim(ctx, theme, "CHAPTER I / ARCANA"); UI.ui_heading(ctx, theme, "A traveller's notes");
            UI.ui_label(ctx, theme, "A little magic for the long road. Choose a spell on the facing page and try it.");
            illustration(130); UI.ui_label_dim(ctx, theme, "Ink, paper, and a spark of curiosity."); UI.ui_separator(ctx, theme);
            if UI.ui_button_ex(ctx, theme, "bookmark", ifx bookmarked then "Remove bookmark" else "Bookmark chapter", .Primary) {
                bookmarked = !bookmarked; status = ifx bookmarked then "Chapter I bookmarked." else "Bookmark removed.";
            }
            UI.ui_label_dim(ctx, theme, "Click the controls printed on the paper.");
        }
        if index == 1 {
            UI.ui_label_dim(ctx, theme, "SPELL INDEX / THREE ENTRIES"); UI.ui_heading(ctx, theme, "Prepared spells");
            names: [3] string = .["01 / Ember lantern", "02 / Forest ward", "03 / Tidal step"];
            for name, i: names if UI.ui_button_ex(ctx, theme, tprint("spell-%", i), name, ifx selected_spell == i then UI.UI_Button_Style.Primary else UI.UI_Button_Style.Normal) selected_spell = i;
            UI.ui_separator(ctx, theme);
            descriptions: [3] string = .["A warm light that never burns out.", "A quiet shield woven from leaves.", "Cross a stream with a single step."];
            UI.ui_label(ctx, theme, descriptions[selected_spell]); UI.ui_progress_bar(ctx, theme, cast(float32) (selected_spell + 1) / 4, 290);
            if UI.ui_button_ex(ctx, theme, "cast", "Cast spell", .Primary) { casts += 1; status = "A spell was cast from the page."; }
            UI.ui_label_dim(ctx, theme, tprint("Spells cast: %", casts));
        }
        if index == 2 {
            UI.ui_label_dim(ctx, theme, "CHAPTER II / PROVISIONS"); UI.ui_heading(ctx, theme, "The satchel");
            UI.ui_label(ctx, theme, "Enough supplies for one more expedition. All changes survive a page turn.");
            illustration(108); UI.ui_separator(ctx, theme);
            UI.ui_label(ctx, theme, tprint("Healing draughts: % / 5", 5 - potions));
            if UI.ui_button_ex(ctx, theme, "potion", "Drink a draught", .Primary, .{disabled = potions >= 5}) { potions += 1; status = "One healing draught used."; }
            UI.ui_label_dim(ctx, theme, "A real button, drawn into the page texture.");
        }
        if index == 3 {
            UI.ui_label_dim(ctx, theme, "CAMP / AUDIO"); UI.ui_heading(ctx, theme, "Quiet moments");
            UI.ui_label(ctx, theme, "Page controls use the same UI widgets as the rest of the game."); UI.ui_separator(ctx, theme);
            C.UI(UI.ui_row_decl(16), #code { UI.ui_label(ctx, theme, "Camp music"); UI.ui_spacer(); UI.ui_toggle(ctx, theme, "music", *music); });
            UI.ui_label(ctx, theme, tprint("Volume / % percent", cast(int) (volume * 100))); UI.ui_slider(ctx, theme, "volume", *volume, width = 290);
            UI.ui_label_dim(ctx, theme, "Drag the thumb directly on the tilted page."); UI.ui_separator(ctx, theme);
            if UI.ui_button(ctx, theme, "reset-audio", "Reset audio") { music = true; volume = 0.65; status = "Audio settings restored."; }
            UI.ui_label_dim(ctx, theme, ifx music then "Camp music is enabled." else "Camp music is muted.");
        }
        if index == 4 {
            UI.ui_label_dim(ctx, theme, "CHAPTER III / THE JOURNEY"); UI.ui_heading(ctx, theme, "A map of the wild");
            UI.ui_label(ctx, theme, "Follow the river north. There is an old observatory beyond the pines."); illustration(160); UI.ui_separator(ctx, theme);
            if UI.ui_button_ex(ctx, theme, "bookmark-map", ifx route_marked then "Remove map marker" else "Mark this route", .Primary) { route_marked = !route_marked; status = "The northern route is marked."; }
        }
        if index == 5 {
            UI.ui_label_dim(ctx, theme, "QUEST LOG / THE OBSERVATORY"); UI.ui_heading(ctx, theme, "Among the stars");
            UI.ui_label(ctx, theme, "Find the keeper's missing lens and bring the night sky back into focus."); UI.ui_separator(ctx, theme);
            UI.ui_label(ctx, theme, "Destination: northern observatory"); UI.ui_label(ctx, theme, "Reward: a new constellation");
            if UI.ui_button_ex(ctx, theme, "quest", ifx quest_accepted then "Quest accepted" else "Accept the quest", .Primary, .{disabled = quest_accepted}) { quest_accepted = true; status = "Quest accepted: Among the stars."; }
            UI.ui_progress_bar(ctx, theme, ifx quest_accepted then 0.25 else 0.0, 290);
            UI.ui_label_dim(ctx, theme, ifx quest_accepted then "Step 1 / Reach the observatory" else "Your next adventure waits here.");
            UI.ui_separator(ctx, theme); UI.ui_label_dim(ctx, theme, "Use Previous to return to your notes.");
        }
    });
    UI.ui_draw(ctx, *page.renderer);
    assert(ctx.error_count == 0 && !ctx.pool_overflow, "Page layout failed");
    if index % 2 == 0 draw_illustration(index);
    target := F.drawable_target_target(page.target); F.graphics_device_clear_color(F.App.device, target, PAPER);
    assert(R.submit(*page.renderer, .{target = target}) == .None);
}
draw_illustration :: (index: int) {
    page := *pages[index]; batch := *page.renderer; box, found := UI.ui_element_rect(*page.ctx, "illustration"); if !found return;
    p := F.Vector2.{box.x + box.w * 0.5, box.y + box.h * 0.5}; ink := F.Color.{88,121,95,255};
    if index == 0 {
        R.circle_line(batch, p, 54, 1.5, 48, ink); R.circle_line(batch, p, 45, 1, 48, .{165,151,105,255});
        R.quad(batch, p + .{0,-38}, p + .{22,0}, p + .{0,38}, p + .{-22,0}, ink);
        R.circle(batch, p, 11, 24, PAPER); R.circle(batch, p, 5, 16, .{179,135,68,255});
    }
    if index == 2 {
        x := p.x - 34; y := box.y + 18;
        R.rect(batch, .{x,y,68,70}, .{133,113,78,255}); R.rect(batch, .{x-5,y,78,26}, .{102,94,68,255});
        R.rect(batch, .{x+27,y+13,14,30}, .{189,159,93,255}); R.circle_line(batch, .{x+34,y-1}, 17, 4, 24, .{102,94,68,255});
    }
    if index == 4 {
        for i: 0..6 { x := box.x + 25 + cast(float32) i * 38; y := box.y + 25 + cast(float32) (i % 3) * 30; R.triangle(batch, .{x,y}, .{x-11,y+22}, .{x+11,y+22}, ink); }
        for i: 0..4 { x := box.x + 75 + cast(float32) i * 32; y0 := box.y + 100 - cast(float32) (i % 2) * 14; y1 := box.y + 100 - cast(float32) ((i+1)%2) * 14; R.line(batch, .{x,y0}, .{x+32,y1}, 3, .{102,149,160,255}); }
        R.circle_line(batch, .{box.x+242,box.y+37}, 12, 2, 24, .{160,110,65,255}); R.line(batch, .{box.x+242,box.y+18}, .{box.x+242,box.y+56}, 1, .{160,110,65,255});
    }
}

