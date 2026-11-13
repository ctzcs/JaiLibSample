// 窗口后备缓冲 → library/screenshots/<name>.png。由已 #load 的文件提供 F / FILE。
// 用法：在 render 里数帧，到目标帧调用 capture_window("basic") 后 F.app_exit()。

capture_frame := 0;

capture_window :: (name: string) {
    back := F.graphics_device_get_backbuffer(F.App.device, F.App.window);
    texture := F.target_texture(back);
    img := F.image_create(texture.Width, texture.Height);
    defer F.image_destroy(*img);
    F.texture_get_data(texture, img.Data);
    bright := 0;
    for p: img.Data if p.r > 40 || p.g > 40 || p.b > 40 bright += 1;
    assert(bright > 100, "GPU output is blank");
    png := F.image_encode_png(*img);
    defer free(png.data);
    assert(FILE.make_directory_if_it_does_not_exist("library/screenshots", true));
    path := tprint("library/screenshots/%-%x%.png", name, texture.Width, texture.Height);
    assert(FILE.write_entire_file(path, cast(string) png));
    print("screenshot: %\n", path);
}
