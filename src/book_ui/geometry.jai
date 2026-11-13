W :: #import "kit/world";
R3 :: #import "kit/rendering/3d";
PAGE_W :: 360;
PAGE_H :: 500;
COLS :: 48;
ROWS :: 12;
PI :: cast(float32) 3.141592653589793;
Sheet :: struct { points: [ROWS + 1][COLS + 1] F.Vector3; normals: [COLS + 1] F.Vector3; }
Book_View :: struct { camera: W.Camera3D; model, inverse_model, mvp: W.Matrix4; w, height: float32; }
Book_Pose :: struct { position: F.Vector3; rotation: [4] float32; }
pose: Book_Pose;
view: Book_View;
sheets: [3] Sheet;
previous_pointer: F.Vector2;
drag_mode: int;

quat_mul :: (a: [4] float32, b: [4] float32) -> [4] float32 {
    av := F.Vector3.{a[0], a[1], a[2]}; bv := F.Vector3.{b[0], b[1], b[2]};
    v := av * b[3] + bv * a[3] + W.v3_cross(av, bv); w := a[3] * b[3] - W.v3_dot(av, bv);
    l := sqrt(W.v3_dot(v, v) + w * w); return .[v.x / l, v.y / l, v.z / l, w / l];
}
quat_axis :: (v: F.Vector3, angle: float32) -> [4] float32 {
    s := sin(angle * 0.5); return .[v.x * s, v.y * s, v.z * s, cos(angle * 0.5)];
}
reset_pose :: () {
    pose = .{.{0, -35, 170}, quat_mul(quat_axis(.{0, 0, 1}, -0.035), quat_mul(quat_axis(.{0, 1, 0}, 0.08), quat_axis(.{1, 0, 0}, -0.38)))};
    drag_mode = 0;
}
update_view :: () {
    view.w = h.ui.width * h.scale; view.height = h.ui.height * h.scale;
    W.camera3d_init(*view.camera, cast(s32) view.w, cast(s32) view.height);
    W.camera3d_set_field_of_view(*view.camera, PI / 4);
    W.camera3d_set_near_clip(*view.camera, 20); W.camera3d_set_far_clip(*view.camera, 6000);
    W.camera3d_set_position(*view.camera, .{0, 0, max(1600 / (view.w / view.height), 1400)});
    W.camera3d_set_target(*view.camera, .{0, 0, 0});
    view.model = W.matrix4_multiply(W.matrix4_from_quaternion(pose.rotation), W.matrix4_translation(pose.position.x, pose.position.y, pose.position.z));
    ok: bool; view.inverse_model, ok = W.matrix4_inverse(view.model); assert(ok);
    view.mvp = W.matrix4_multiply(view.model, W.camera3d_view_projection(*view.camera));
}
project :: (p: F.Vector3) -> F.Vector2 {
    v := W.matrix4_transform_vec4(view.mvp, .[p.x, p.y, p.z, 1]);
    if v[3] <= 0.001 return .{-10000, -10000};
    return .{(v[0] / v[3] + 1) * view.w * 0.5, (1 - v[1] / v[3]) * view.height * 0.5};
}
make_sheet :: (angle: float32, curl: float32, base_z: float32 = 0) -> Sheet {
    s: Sheet; x, z: float32;
    for col: 0..COLS {
        u := cast(float32) col / COLS;
        if col > 0 { mid := angle - curl * (u - 0.5 / COLS); x += cos(mid) * PAGE_W / COLS; z += sin(mid) * PAGE_W / COLS; }
        tangent := angle - curl * u; s.normals[col] = .{-sin(tangent), 0, cos(tangent)};
        for row: 0..ROWS s.points[row][col] = .{x, (0.5 - cast(float32) row / ROWS) * PAGE_H, z + base_z};
    }
    return s;
}
ray_triangle :: (ray: W.Ray3D, a: F.Vector3, b: F.Vector3, c: F.Vector3, ua: F.Vector2, ub: F.Vector2, uc: F.Vector2) -> (uv: F.Vector2, distance: float32, back: bool, hit: bool) {
    ab := b - a; ac := c - a; p := W.v3_cross(ray.direction, ac); det := W.v3_dot(ab, p);
    if abs(det) < 0.00001 return .{}, 0, false, false;
    s := ray.origin - a; u := W.v3_dot(s, p) / det; q := W.v3_cross(s, ab); v := W.v3_dot(ray.direction, q) / det;
    distance = W.v3_dot(ac, q) / det;
    if u < -0.00001 || v < -0.00001 || u + v > 1.00001 || distance < 0 return .{}, 0, false, false;
    return ua * (1 - u - v) + ub * u + uc * v, distance, det < 0, true;
}
pick_book :: (p: F.Vector2) -> (page: int, uv: F.Vector2) {
    page = -1; ray, ok := W.camera3d_screen_point_to_ray(*view.camera, p); if !ok return page, uv;
    ray.origin, ok = W.matrix4_transform_point(view.inverse_model, ray.origin); if !ok return page, uv;
    ray, ok = W.ray3d_make(ray.origin, W.matrix4_transform_vector(view.inverse_model, ray.direction)); if !ok return page, uv;
    nearest: float32 = 1e30;
    for box: binding_boxes { d, hit := W.ray3d_hit_aabb(ray, box.lo, box.hi); if hit nearest = min(nearest, d); }
    count := ifx direction == 0 then 2 else 3;
    for i: 0..count-1 for row: 0..ROWS-1 for col: 0..COLS-1 {
        sheet := *sheets[i]; a := sheet.points[row][col]; b := sheet.points[row][col + 1]; c := sheet.points[row + 1][col + 1]; d := sheet.points[row + 1][col];
        u0 := cast(float32) col / COLS; u1 := cast(float32) (col + 1) / COLS; v0 := cast(float32) row / ROWS; v1 := cast(float32) (row + 1) / ROWS;
        for tri: 0..1 {
            coords: F.Vector2; dist: float32; back, hit: bool;
            if tri == 0 coords, dist, back, hit = ray_triangle(ray, a, c, b, .{u0, v0}, .{u1, v1}, .{u1, v0});
            else coords, dist, back, hit = ray_triangle(ray, a, d, c, .{u0, v0}, .{u0, v1}, .{u1, v1});
            if hit && dist < nearest {
                nearest = dist; uv = coords; if back uv.x = 1 - uv.x;
                page = ifx i < 2 && back == (i == 0) then spread * 2 + i else -1;
            }
        }
    }
    return page, uv;
}
manipulate :: () {
    if h.smoke return;
    mouse := F.input_mouse(F.App.input); key := F.input_keyboard(F.App.input); pointer := h.pointer * h.scale;
    if F.keyboard_pressed(key, .R) reset_pose();
    if drag_mode == 0 && !UI.ui_input_capture(*h.ui).pointer {
        if F.mouse_pressed(mouse, .RIGHT) { drag_mode = ifx F.keyboard_shift(key) then 2 else 1; previous_pointer = pointer; }
        else if F.mouse_pressed(mouse, .MIDDLE) { drag_mode = 3; previous_pointer = pointer; }
        pose.position.z = clamp(pose.position.z + mouse.WheelValue.y * 65, -2000, 650);
    }
    if drag_mode != 0 {
        if !F.mouse_down(mouse, ifx drag_mode == 3 then F.Mouse_Buttons.MIDDLE else F.Mouse_Buttons.RIGHT) { drag_mode = 0; return; }
        delta := pointer - previous_pointer;
        if drag_mode == 3 {
            k := 2 * (view.camera.position.z - pose.position.z) * tan(PI / 8) / view.height;
            pose.position += .{delta.x * k, -delta.y * k, 0};
        } else {
            q := ifx drag_mode == 2 then quat_axis(.{0, 0, 1}, -delta.x * 0.008) else quat_mul(quat_axis(.{0, 1, 0}, delta.x * 0.008), quat_axis(.{1, 0, 0}, delta.y * 0.008));
            pose.rotation = quat_mul(q, pose.rotation);
        }
        previous_pointer = pointer;
    }
}

