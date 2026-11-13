// 中文 UI 验证：用 shared/msdf_font 的 Noto Sans CJK SC MSDF 图集注册 kit/ui 字体。
// 加 `-- cjk` 走中文图集；不加则退回内置 Roboto（会显示缺字），用来对比。
#load "../../shared/ui_sample.jai";

PAPER :: F.Color.{237, 222, 191, 255};
MUTED :: F.Color.{163, 156, 139, 255};
ACCENT :: F.Color.{219, 175, 89, 255};
clicks: int;

main :: () { sample_run("cjk_ui", 900, 560); }

sample_start :: () {
    h.theme.text = PAPER;
    h.theme.text_dim = MUTED;
    h.theme.accent = ACCENT;
    h.theme.button = .{147, 53, 43, 255};
    h.theme.button_hover = .{175, 70, 53, 255};
    h.theme.panel = .{26, 30, 38, 245};
    h.theme.body_font_size = 18;
    h.theme.padding = 14;
}

sample_stop :: () {}
sample_update :: () {
    if !h.smoke && F.keyboard_pressed(F.input_keyboard(F.App.input), .ESCAPE) F.app_exit();
}
sample_after_ui :: () {}

sample_draw :: () {
    root_element();
    C.UI(anchor("card", 36, 32, h.ui.width - 72, 420), #code {
        label("中文字体 / MSDF 图集", 15, ACCENT);
        label("渲染中文标题与正文", 34, PAPER);
        label("这一页的文字全部来自 Noto Sans CJK SC 子集图集，字形在离线阶段烘焙成多通道距离场，运行时只采样。", 16, MUTED);
        label("常用标点、数字与符号：，。！？：；（）《》——…… 0123456789 +-*/%", 16, MUTED);
        label(tprint("按钮点击次数：%", clicks), 16, ACCENT);
        C.UI(UI.ui_row_decl(10), #code {
            if UI.ui_button(*h.ui, *h.theme, "cjk-button", "点我一下") clicks += 1;
            if UI.ui_button(*h.ui, *h.theme, "cjk-reset", "清零") clicks = 0;
        });
    });
}

sample_test_input :: () {
    f := h.frame;
    if f == 3 || f == 4 test_click("cjk-button", f == 3);
}

sample_test_check :: () {
    if h.frame == 6 assert(clicks == 1, "中文按钮点击");
    if h.frame == 8 h.done = true;
}
