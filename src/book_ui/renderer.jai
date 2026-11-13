Book_Vertex :: struct { position, normal: F.Vector3; uv: F.Vector2; color: [4] float32; }
Binding_Box :: struct { lo, hi: F.Vector3; color: [4] float32; }
binding_boxes: [3] Binding_Box = .[
    .{.{-375, -265, -24}, .{375, 265, -16}, .[0.17, 0.27, 0.25, 1]},
    .{.{-363, -251, -16}, .{-2, 251, -1}, .[0.84, 0.80, 0.65, 1]},
    .{.{2, -251, -16}, .{363, 251, -1}, .[0.84, 0.80, 0.65, 1]}];
meshes: [4] *F.Mesh;
vertex_shader, fragment_shader: *F.Shader;
material: *F.Material;
book_target: *F.Target;
white: *F.Texture;
scene: R.Render2D;
VS_SPV :: #run embed_file(tprint("%/shaders/Compiled/Book.vertex.spv", #filepath));
VS_DXIL :: #run embed_file(tprint("%/shaders/Compiled/Book.vertex.dxil", #filepath));
FS_SPV :: #run embed_file(tprint("%/shaders/Compiled/Book.fragment.spv", #filepath));
FS_DXIL :: #run embed_file(tprint("%/shaders/Compiled/Book.fragment.dxil", #filepath));
renderer_start :: () {
    device := F.App.device;
    vs := MAT.shader_pick(device.driver, .{spv = cast([] u8) VS_SPV, dxil = cast([] u8) VS_DXIL});
    fs := MAT.shader_pick(device.driver, .{spv = cast([] u8) FS_SPV, dxil = cast([] u8) FS_DXIL});
    assert(vs.count > 0 && fs.count > 0, "Book shaders require D3D12 or Vulkan");
    vertex_shader = F.shader_create(device, .VERTEX, vs, uniform_buffer_count = 1, entry_point = "vertex_main");
    fragment_shader = F.shader_create(device, .FRAGMENT, fs, sampler_count = 2, entry_point = "fragment_main");
    assert(vertex_shader.handle != 0 && fragment_shader.handle != 0);
    material = F.material_create(vertex_shader, fragment_shader);
    elements: [4] F.Vertex_Format_Element = .[.{0, .FLOAT3, false}, .{1, .FLOAT3, false}, .{2, .FLOAT2, false}, .{3, .FLOAT4, false}];
    format := F.vertex_format_make(elements, size_of(Book_Vertex));
    for *mesh: meshes mesh.* = F.mesh_create(device, format, .THIRTY_TWO);
    white = F.texture_create_from_colors(device, 1, 1, .[F.Color_White]);
    assert(R.init(*scene, *h.materials) == "");
    vertices: [..] Book_Vertex; indices: [..] u32;
    defer array_free(vertices); defer array_free(indices);
    for box: binding_boxes append_box(*vertices, *indices, box);
    for layer: 0..5 for side: 0..1 {
        x: float32 = ifx side == 0 then -363.0 else 2.0; z := -15 + cast(float32) layer * 2.2;
        append_box(*vertices, *indices, .{.{x, -251.2, z}, .{x + 361, -250.8, z + 0.5}, .[0.63, 0.58, 0.43, 1]});
        append_box(*vertices, *indices, .{.{x, 250.8, z}, .{x + 361, 251.2, z + 0.5}, .[0.63, 0.58, 0.43, 1]});
    }
    append_box(*vertices, *indices, .{.{-3, -264, -16}, .{3, 264, -0.7}, .[0.16, 0.23, 0.20, 1]});
    F.mesh_set_vertices(meshes[3], vertices); F.mesh_set_indices(meshes[3], indices);
}
append_box :: (vertices: *[..] Book_Vertex, indices: *[..] u32, box: Binding_Box) {
    a := box.lo; b := box.hi;
    corners: [8] F.Vector3 = .[.{a.x,a.y,a.z}, .{b.x,a.y,a.z}, .{b.x,b.y,a.z}, .{a.x,b.y,a.z}, .{a.x,a.y,b.z}, .{b.x,a.y,b.z}, .{b.x,b.y,b.z}, .{a.x,b.y,b.z}];
    faces: [6][4] int = .[.[0,3,2,1], .[4,5,6,7], .[0,1,5,4], .[3,7,6,2], .[0,4,7,3], .[1,2,6,5]];
    normals: [6] F.Vector3 = .[.{0,0,-1}, .{0,0,1}, .{0,-1,0}, .{0,1,0}, .{-1,0,0}, .{1,0,0}];
    for face, i: faces {
        base := cast(u32) vertices.count;
        for corner: face array_add(vertices, .{corners[corner], normals[i], .{}, box.color});
        for offset: u32.[0,1,2,0,2,3] array_add(indices, base + offset);
    }
}
upload_sheet :: (mesh: *F.Mesh, sheet: *Sheet) {
    vertices: [(COLS + 1) * (ROWS + 1)] Book_Vertex; indices: [COLS * ROWS * 6] u32;
    for row: 0..ROWS for col: 0..COLS {
        gutter := 0.84 + 0.16 * min(cast(float32) col / 5, 1);
        vertices[row * (COLS + 1) + col] = .{sheet.points[row][col], sheet.normals[col], .{cast(float32) col / COLS, cast(float32) row / ROWS}, .[gutter,gutter,gutter,1]};
    }
    for row: 0..ROWS-1 for col: 0..COLS-1 {
        a := cast(u32) (row * (COLS + 1) + col); b := a + 1; d := a + COLS + 1; c := d + 1; i := (row * COLS + col) * 6;
        // jfoster uses clockwise raster front faces. Reverse the source mesh winding
        // so SV_IsFrontFace matches the logical page front used by ray picking.
        indices[i] = a; indices[i+1] = b; indices[i+2] = c; indices[i+3] = a; indices[i+4] = c; indices[i+5] = d;
    }
    F.mesh_set_vertices(mesh, vertices); F.mesh_set_indices(mesh, indices);
}
draw_mesh :: (index: int, front: *F.Texture, back: *F.Texture) {
    sampler := F.texture_sampler_make(.LINEAR, .CLAMP);
    material.Fragment.Samplers[0] = .{Tex = front, Sampler = sampler};
    material.Fragment.Samplers[1] = .{Tex = back, Sampler = sampler};
    cmd := F.draw_command_from_mesh(F.drawable_target_target(book_target), meshes[index], material);
    cmd.DepthTestEnabled = true; cmd.DepthWriteEnabled = true; cmd.CullMode = .NONE;
    F.graphics_device_draw(F.App.device, cmd);
}
page_texture :: (index: int) -> *F.Texture { return F.target_texture(pages[index].target); }
render_book :: () {
    w := cast(s32) view.w; height := cast(s32) view.height;
    if book_target == null || book_target.Width != w || book_target.Height != height {
        if book_target != null { F.target_dispose(book_target); free(book_target); }
        book_target = F.target_create_formats(F.App.device, w, height, .[.COLOR, .DEPTH32]);
    }
    F.graphics_device_clear(F.App.device, F.drawable_target_target(book_target), .[F.Color.{0,0,0,0}], 1, 0, .COLOR | .DEPTH);
    matrices: [R3.VERTEX_MATRIX_BLOCK_SIZE] u8; assert(R3.pack_vertex_matrix_block(matrices, view.mvp, view.model));
    F.material_stage_set_uniform(*material.Vertex, 0, matrices);
    draw_mesh(3, white, white);
    left := spread * 2; right := left + 1;
    if direction > 0 right += 2;
    if direction < 0 left -= 2;
    upload_sheet(meshes[0], *sheets[0]); upload_sheet(meshes[1], *sheets[1]);
    draw_mesh(0, white, page_texture(left)); draw_mesh(1, page_texture(right), white);
    if direction != 0 {
        front := ifx direction > 0 then spread * 2 + 1 else spread * 2 - 1;
        upload_sheet(meshes[2], *sheets[2]); draw_mesh(2, page_texture(front), page_texture(front + 1));
    }
    R.reset(*scene);
    for i: 0..19 { y := cast(float32) i * view.height / 20; R.line(*scene, .{0,y}, .{view.w,y+45}, 1, .{27,35,38,255}); }
    R.quad_texture(*scene, F.target_texture(book_target), .{0,0}, .{view.w,0}, .{view.w,view.height}, .{0,view.height}, .{0,0}, .{1,0}, .{1,1}, .{0,1});
    assert(R.submit(*scene, .{target = F.drawable_target_window(F.App.window)}) == .None);
}
renderer_stop :: () {
    for mesh: meshes { F.mesh_dispose(mesh); free(mesh); }
    F.material_destroy(material); F.shader_dispose(vertex_shader); free(vertex_shader); F.shader_dispose(fragment_shader); free(fragment_shader);
    F.texture_dispose(white); free(white); if book_target != null { F.target_dispose(book_target); free(book_target); }
    R.dispose(*scene);
}

