#load "../../shared/scene3d.jai";
mesh, swarm_mesh: F.Mesh;
materials: [2] *MAT.Material;
swarm_material: *MAT.Material;
instances: R3.Model_Buffer;
items: [] R3.Model_Item;
values: [][4] float32;
outline: bool = true;
grouped: bool = true;
swarm_on, automatic, each, views, swarm_ready: bool;
draws, count: int;
main :: () { scene_run("material3d"); }
scene_start :: () {
    scene_perf_enabled=true;
    scene_register("src/shader_lab/shaders/Compiled");
    for *m: materials m.* = scene_load_material("src/material3d/material.json");
    assert(MAT.material_set_number(materials[1], "Outlined_body", "hue", .[0.7,0,0,0]));
    p := sphere(int_arg("rings=",24),int_arg("segments=",48)); defer primitive_free(*p);
    assert(R3.mesh_upload(*mesh, F.App.device, *p));
    automatic = has_arg("models"); each = has_arg("each"); views = has_arg("views");
    grouped=!has_arg("ungrouped"); outline=!has_arg("nooutline");
    h.inset=F.target_create_formats(F.App.device,320,200,.[.COLOR,.DEPTH32]);
    swarm_on = has_arg("swarm") || automatic;
    count = int_arg("count=", ifx automatic then 4096 else 1000000);
    if swarm_on swarm_init();
}
swarm_hash :: (i: int) -> float32 { return cast(float32) ((i * 16807 + 12345) % 65536) / 65536; }
swarm_init :: () {
    if swarm_ready return;
    p := sphere(int_arg("rings=", 2), int_arg("segments=", 4)); defer primitive_free(*p);
    assert(R3.mesh_upload(*swarm_mesh, F.App.device, *p));
    swarm_material = scene_load_material("src/material3d/swarm.json");
    hue := MAT.instance_slot(swarm_material, "hue"); motion := MAT.instance_slot(swarm_material, "motion");
    assert(hue.valid && motion.valid);
    slots := MAT.instance_slot_count(swarm_material);
    items = NewArray(count, R3.Model_Item); values = NewArray(count * slots, [4] float32);
    side := cast(int) ceil(pow(cast(float32) count, cast(float32) (1.0/3.0)));
    half := cast(float32) side * 0.5;
    for *item, i: items {
        layer := i / (side*side); if !has_arg("back") layer = side-1-layer;
        x := cast(float32) (i % side); y := cast(float32) ((i / side) % side); z := cast(float32) layer;
        scale := 0.1 + 0.14*swarm_hash(i);
        item.world = W.matrix4_multiply(W.matrix4_scaling(scale,scale,scale), W.matrix4_translation((x-half)*0.6,(y-half)*0.6,(z-half)*0.6));
        item.tint = .[0.75+0.25*swarm_hash(i),0.8,1,1];
        assert(MAT.instance_array_set(values, slots, i, hue, z/cast(float32) side));
        assert(MAT.instance_array_set(values, slots, i, motion, 6.2831853*swarm_hash(i*7),0.6+1.4*swarm_hash(i*11),0.05+0.15*swarm_hash(i*13)));
    }
    if !automatic {
        assert(R3.model_buffer_init(*instances, swarm_material, count, "swarm") == "");
        assert(R3.model_buffer_upload(*instances, items, 0, values));
    }
    h.distance = max(cast(float32) 5, cast(float32) side * 0.9);
    swarm_ready = true;
}
scene_update :: () {
    keys := F.input_keyboard(F.App.input);
    if F.keyboard_pressed(keys, .SPACE) outline = !outline;
    if F.keyboard_pressed(keys, .G) grouped = !grouped;
    if F.keyboard_pressed(keys, .V) views = !views;
    if F.keyboard_pressed(keys, .I) { swarm_on = !swarm_on; if swarm_on swarm_init(); else h.distance = 6; }
    if F.keyboard_pressed(keys, .R) {
        R3.clear(*h.renderer);
        reason := MAT.material_reload(*h.materials, materials[0]);
        if reason != "" print("Reload failed: %\n", reason);
    }
}
scene_draw :: (view: R3.View) {
    draws = 0;
    if swarm_on {
        if automatic {
            if each {
                slots := MAT.instance_slot_count(swarm_material);
                for item, i: items {
                    instance := MAT.instance_values_from(array_view(values, i*slots, slots));
                    assert(R3.model(*h.renderer, *swarm_mesh, swarm_material, item.world, null, *instance) == .None);
                }
            } else assert(R3.models(*h.renderer, *swarm_mesh, swarm_material, items, null, values) == .None);
        } else assert(R3.buffer(*h.renderer, *swarm_mesh, swarm_material, *instances, count) == .None);
    } else {
        objects := int_arg("objects=", 2);
        for i: 0..objects-1 {
            transform := W.matrix4_translation(ifx i == 0 then -1.25 else 1.25,0,0);
            if objects > 2 {
                side := cast(int) ceil(sqrt(cast(float32) objects)); spacing := cast(float32) 5 / cast(float32) side;
                transform = W.matrix4_multiply(W.matrix4_scaling(spacing*0.43,spacing*0.43,spacing*0.43),
                    W.matrix4_translation((cast(float32) (i%side)-cast(float32) side*0.5)*spacing,(cast(float32) (i/side)-cast(float32) side*0.5)*spacing,0));
            }
            assert(R3.model(*h.renderer, *mesh, materials[ifx objects>2 then 0 else i%2], transform) == .None);
        }
    }
    h.show_inset=views;
    pass := ifx grouped || !outline || swarm_on then "body" else "";
    assert(R3.submit(*h.renderer, view, pass) == .None); draws += h.renderer.draw_calls;
    if grouped && outline && !swarm_on {
        assert(R3.submit(*h.renderer, view, "outline") == .None); draws += h.renderer.draw_calls;
    }
    if views {
        camera:=h.camera; W.camera3d_set_viewport(*camera,320,200);
        W.camera3d_set_position(*camera,.{h.distance*.7,h.distance*.5,h.distance*.6});
        target:=F.drawable_target_target(h.inset); F.graphics_device_clear(F.App.device,target,.[F.Color.{22,28,38,255}],1,0,.COLOR|.DEPTH);
        second:=R3.View.{target=target,view_projection=W.camera3d_view_projection(*camera),view_matrix=W.camera3d_view(*camera),time=h.time};
        assert(R3.submit(*h.renderer,second,pass)==.None);
        if grouped && outline && !swarm_on assert(R3.submit(*h.renderer,second,"outline")==.None);
    }
}
scene_check :: () {
    assert(draws > 0);
    if swarm_on assert(h.renderer.instances == count);
    assert(materials[0] != materials[1]);
    assert(scene_perf.initialized && scene_perf.visible);
    if views {
        image:=F.image_create(h.inset.Width,h.inset.Height); defer F.image_destroy(*image);
        F.texture_get_data(F.target_texture(h.inset),image.Data);
        changed:=0; for p:image.Data if p.r!=22 || p.g!=28 || p.b!=38 changed+=1;
        assert(changed>100,"Second camera view is blank");
    }
    print("material3d: % draws, % instances\n", draws, h.renderer.instances);
}
scene_stop :: () {
    R3.mesh_dispose(*mesh); R3.mesh_dispose(*swarm_mesh); R3.model_buffer_dispose(*instances);
    free(items.data); free(values.data);
}
