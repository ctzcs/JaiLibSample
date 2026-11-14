// olib_sample/src/backend 的 Jai 版本：stb_truetype 字体后端（字形索引、
// 度量与像素栅格化）。使用 JaiLib 内置 Noto OTF，不依赖系统字体。
#import "Basic";
F :: #import "foster";
#load "../../shared/library_assets.jai";

main :: () {
    font := sample_load_bitmap_font();
    assert(font != null, "Built-in Noto font failed to load");
    defer F.font_destroy(font);
    scale := F.font_get_scale(font, 24);
    ch := F.font_get_character(font, 65, 24); // 65 = 'A'（Jai 没有字符字面量）

    count := ch.Width * ch.Height;
    pixels: [] F.Color = .{ count, cast(*F.Color) alloc(cast(s64) (count * size_of(F.Color))) };
    if count > 0 F.font_get_pixels(font, pixels, ch.GlyphIndex, ch.Width, ch.Height, scale, true);

    print("metrics: ascent %, descent %, glyph % size (% x %), pixels %\n",
        font.Ascent, font.Descent, ch.GlyphIndex, ch.Width, ch.Height, pixels.count);
    covered:=0; for pixel:pixels if pixel.a>0 covered+=1;
    assert(covered>0 && covered<count,"Font rasterizer returned a blank or solid glyph");
    free(pixels.data);
    assert(ch.GlyphIndex > 0 && count > 0);
    print("[backend] FONT PASS\n");
}
