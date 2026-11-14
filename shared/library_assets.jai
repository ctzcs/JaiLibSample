#scope_file
Asset_File :: #import "File";
#scope_export

// Source-relative paths do not depend on the process working directory.
sample_library_asset_path :: (relative: string) -> string {
    return tprint("%/../../JaiLib/assets/%", #filepath, relative);
}

sample_embed_library_asset :: (relative: string) -> string {
    bytes, ok := Asset_File.read_entire_file(sample_library_asset_path(relative));
    assert(ok && bytes.count > 0, "Missing JaiLib built-in asset: %", relative);
    return bytes;
}

SAMPLE_MSDF_JSON :: #run sample_embed_library_asset("fonts/msdf/ui.json");
SAMPLE_MSDF_PNG :: #run sample_embed_library_asset("fonts/msdf/ui.png");
SAMPLE_NOTO_OTF :: #run sample_embed_library_asset("fonts/NotoSansCJKsc-Regular-subset.otf");
SAMPLE_NOTO_PATH :: #run sample_library_asset_path("fonts/NotoSansCJKsc-Regular-subset.otf");

SAMPLE_NOTO_C_PATH :: #run tprint("%\0", SAMPLE_NOTO_PATH);

// Foster takes ownership of bitmap-font bytes; embedded bytes must be copied.
sample_load_bitmap_font :: () -> *F.Font {
    owned := copy_string(SAMPLE_NOTO_OTF);
    font := F.font_load_bytes(cast([] u8) owned);
    if font == null free(owned.data);
    return font;
}
