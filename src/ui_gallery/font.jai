// jfoster loads msdf-atlas-gen metrics as em units and atlas bounds as pixels.
// JaiLib kit/ui currently expects LineHeight in pixels and normalized atlas UVs.
// Adapt a borrowed top-origin font without mutating device-owned cached resources.
// Accepts Foster Roboto and JaiLib Noto MSDF atlases, both with yOrigin = top.
prepare_ui_font :: (source: *F.Msdf_Font, view: *F.Msdf_Font) {
    view.* = source.*;
    glyphs: [..] F.Msdf_Font_Glyph;
    view.Glyphs = glyphs;
    view.LineHeight = source.LineHeight * source.Size;
    width := cast(float32) source.Atlas.Width;
    height := cast(float32) source.Atlas.Height;
    for glyph: source.Glyphs {
        normalized := glyph;
        normalized.al /= width;
        normalized.ar /= width;
        normalized.at /= height;
        normalized.ab /= height;
        array_add(*view.Glyphs, normalized);
    }
}
