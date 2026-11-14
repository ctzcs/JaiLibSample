// 中文 UI 默认嵌入 JaiLib/assets/fonts/msdf；roboto 参数显式切换到 Latin 字体作对照。
#load "../../shared/ui_sample.jai";

PAPER :: F.Color.{ 237, 222, 191, 255 };
MUTED :: F.Color.{ 163, 156, 139, 255 };
ACCENT :: F.Color.{ 219, 175, 89, 255 };
clicks: int;

main :: () {
    sample_run("cjk_ui", 900, 560);
}

sample_start :: () {
    h.theme.text = PAPER;
    h.theme.text_dim = MUTED;
    h.theme.accent = ACCENT;
    h.theme.button = .{ 147, 53, 43, 255 };
    h.theme.button_hover = .{ 175, 70, 53, 255 };
    h.theme.panel = .{ 26, 30, 38, 245 };
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
        label("JaiLib 内置字体图集：离线生成，加载后显示中文。", 16, MUTED);
        label("标点、数字与符号：，。：；（） 0123456789 +-*/%", 16, MUTED);
        label(tprint("点击次数：%", clicks), 16, ACCENT);
        C.UI(UI.ui_row_decl(10), #code {
            if UI.ui_button(*h.ui, *h.theme, "cjk-button", "点击") clicks += 1;
            if UI.ui_button(*h.ui, *h.theme, "cjk-reset", "重置") clicks = 0;
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
