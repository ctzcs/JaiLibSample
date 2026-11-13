// olib_sample/src/basic 的 Jai 版本：foster 的最低层用法——
// 自建网格 + 1x1 白纹理 + 离屏 Target，先画到离屏再贴到窗口。
#import "Basic";
M :: #import "Math";
using M;
F :: #import "foster";
FILE :: #import "File";

#load "../../shared/capture.jai";

quad_mesh: *F.Mesh;
quad_material: *F.Material;
quad_texture: *F.Texture;
offscreen_target: *F.Target;
quad_command, offscreen_command: F.Draw_Command;

has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}

startup :: () {
    quad_mesh = F.mesh_create(F.App.device, F.Batcher_Vertex_Format, .SIXTEEN, "SampleQuad");
    verts := F.Batcher_Vertex.[
        .{ .{ -0.5, -0.5 }, .{ 0, 1 }, F.Color_Red,   F.Batcher_Mode_Normal },
        .{ .{ -0.5,  0.5 }, .{ 0, 0 }, F.Color_Green, F.Batcher_Mode_Normal },
        .{ .{  0.5,  0.5 }, .{ 1, 0 }, F.Color_Blue,  F.Batcher_Mode_Normal },
        .{ .{ -0.5, -0.5 }, .{ 0, 1 }, F.Color_Red,   F.Batcher_Mode_Normal },
        .{ .{  0.5,  0.5 }, .{ 1, 0 }, F.Color_Blue,  F.Batcher_Mode_Normal },
        .{ .{  0.5, -0.5 }, .{ 1, 1 }, F.Color_White, F.Batcher_Mode_Normal },
    ];
    F.mesh_set_vertices(quad_mesh, verts);
    indices: [6] u16 = .[ 0, 1, 2, 3, 4, 5 ];
    F.mesh_set_indices(quad_mesh, indices);

    quad_texture = F.texture_create_from_colors(F.App.device, 1, 1, .[ F.Color_White ]);
    offscreen_target = F.target_create(F.App.device, 256, 256, "SampleTarget");

    quad_material = F.defaults_batch_material(F.App.device);
    quad_material.Fragment.Samplers[0] = .{ Tex = quad_texture,
        Sampler = F.texture_sampler_make(.LINEAR, .CLAMP) };

    offscreen_command = F.draw_command_from_mesh(F.drawable_target_target(offscreen_target),
        quad_mesh, quad_material);
    quad_command = F.draw_command_from_mesh(F.drawable_target_window(F.App.window),
        quad_mesh, quad_material);
    print("startup: %\n", F.App.name);
}

shutdown :: () {
    F.target_dispose(offscreen_target);
    F.texture_dispose(quad_texture);
    F.mesh_dispose(quad_mesh);
    print("shutdown: %\n", F.App.name);
}

update :: () {}

render :: () {
    if has_arg("shot") capture_frame += 1;
    sampler := F.texture_sampler_make(.LINEAR, .CLAMP);
    // 顶点已在裁剪空间：给 Batcher Shader 的 b0 传单位矩阵（默认材质不会自己设置投影）。
    identity := M.Matrix4.{};
    identity._11 = 1; identity._22 = 1; identity._33 = 1; identity._44 = 1;
    F.material_stage_set_uniform_value(*quad_material.Vertex, 0, identity);

    F.graphics_device_clear_color(F.App.device, F.drawable_target_target(offscreen_target),
        F.Color_Transparent);
    quad_material.Fragment.Samplers[0] = .{ Tex = quad_texture, Sampler = sampler };
    F.graphics_device_draw(F.App.device, offscreen_command);

    F.graphics_device_clear_color(F.App.device, F.drawable_target_window(F.App.window), F.Color_Black);
    quad_material.Fragment.Samplers[0] = .{ Tex = F.target_texture(offscreen_target), Sampler = sampler };
    F.graphics_device_draw(F.App.device, quad_command);
    if has_arg("shot") && capture_frame == 8 {
        capture_window("basic");
        F.app_exit();
    }
}

main :: () {
    F.App.startup = startup;
    F.App.shutdown = shutdown;
    F.App.update = update;
    F.App.render = render;
    F.app_run(.{application_name = "FosterOdin", window_title = "JaiLib / basic",
        width = 640, height = 360, update_mode = F.update_mode_unlocked()});
    print("foster started: %\n", F.App.name);
    F.app_destroy();
}
