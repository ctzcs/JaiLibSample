// olib_sample/src/backend 的 Jai 版本：stb_truetype 字体后端（字形索引、
// 度量与像素栅格化）。字体文件在系统缺失时打印 font-file-unavailable。
#import "Basic";
F :: #import "foster";

main :: () {
    data, ok := F.json_read_file("C:/Windows/Fonts/AGENCYB.TTF");
    if !ok {
        print("font-file-unavailable\n");
        return;
    }

    font := F.font_load_bytes(cast([] u8) data);
    if font == null {
        print("font-file-unavailable\n");
        free(data);
        return;
    }
    scale := F.font_get_scale(font, 24);
    ch := F.font_get_character(font, 65, 24);   // 65 = 'A'（Jai 没有字符字面量）

    count := ch.Width * ch.Height;
    pixels: [] F.Color = .{ count, cast(*F.Color) alloc(cast(s64) (count * size_of(F.Color))) };
    if count > 0 F.font_get_pixels(font, pixels, ch.GlyphIndex, ch.Width, ch.Height, scale, true);

    print("metrics: ascent %, descent %, glyph % size (% x %), pixels %\n",
        font.Ascent, font.Descent, ch.GlyphIndex, ch.Width, ch.Height, pixels.count);
    free(pixels.data);
    F.font_destroy(font);
}
