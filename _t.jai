#import "Basic";
F :: #import "foster";
J :: "{\"atlas\":{\"type\":\"msdf\",\"distanceRange\":4,\"size\":16,\"width\":16,\"height\":16,\"yOrigin\":\"bottom\"},\"metrics\":{\"emSize\":1,\"lineHeight\":1.25,\"ascender\":0.9,\"descender\":-0.2,\"underlineY\":-0.1,\"underlineThickness\":0.05},\"glyphs\":[{\"unicode\":65,\"advance\":0.6,\"planeBounds\":{\"left\":0,\"top\":-0.8,\"right\":0.5,\"bottom\":0.1},\"atlasBounds\":{\"left\":1,\"top\":2,\"right\":9,\"bottom\":12}}],\"kerning\":[]}"
main :: () {
    print("len=%
", J.count);
    j, ok := F.json_parse(J);
    print("parse=%
", ok);
    if ok F.json_destroy(j);
    img := F.image_create(8, 8, F.Color_Transparent);
    png := F.image_encode_png(img);
    f := F.msdf_font_load_bytes(cast([] u8) J, png);
    print("msdf=%
", f != null);
    free(png.data);
    F.image_destroy(*img);
}
