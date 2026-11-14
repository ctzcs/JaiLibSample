#load "../../shared/scene3d.jai";
Object :: struct { mesh: F.Mesh; color: [4] float32; metallic,roughness: float32; position: W.Vec3; scale: W.Vec3; spin: float32; }
objects: [5] Object;
queue: R3.Render_Queue(int);
vertex,fragment: *F.Shader;
material: *F.Material;
draws: int;
alpha_probe:int;
main :: () { scene_run("forward3d"); }
scene_start :: () {
    extension:=ifx F.App.device.driver==.VULKAN then "spv" else "dxil";
    vs,ok:=FILE.read_entire_file(tprint("src/forward3d/shaders/Compiled/Standard3D.vertex.%",extension)); assert(ok); defer free(vs.data);
    fs,fsok:=FILE.read_entire_file(tprint("src/forward3d/shaders/Compiled/Standard3D.fragment.%",extension)); assert(fsok); defer free(fs.data);
    vertex=F.shader_create(F.App.device,.VERTEX,cast([] u8) vs,uniform_buffer_count=2,entry_point="vertex_main");
    fragment=F.shader_create(F.App.device,.FRAGMENT,cast([] u8) fs,sampler_count=9,uniform_buffer_count=4,entry_point="fragment_main");
    material=F.material_create(vertex,fragment);
    objects=.[
        .{color=.[0.42,0.44,0.40,1],roughness=0.9,position=.{0,-0.51,0},scale=.{12,1,12}},
        .{color=.[0.8,0.22,0.18,1],roughness=0.5,position=.{-2.2,0.7,-0.3},scale=.{1.4,1.4,1.4},spin=0.6},
        .{color=.[0.95,0.75,0.35,1],metallic=1,roughness=0.3,position=.{0.3,0.9,-0.8},scale=.{0.9,0.9,0.9}},
        .{color=.[0.25,0.55,0.95,0.45],roughness=0.15,position=.{2.2,0.75,0.6},scale=.{0.75,0.75,0.75}},
        .{color=.[0.3,0.9,0.45,0.5],roughness=0.4,position=.{1.3,0.45,2},scale=.{0.9,0.9,0.9},spin=-0.4}];
    for *o,i: objects {
        p:=ifx i==2 || i==3 then sphere(24,48) else cube(); defer primitive_free(*p);
        assert(R3.mesh_upload(*o.mesh,F.App.device,*p));
    }
    h.focus=.{0,0.6,0}; h.distance=8.9; h.pitch=0.3;
}
object_world :: (o: *Object) -> W.Matrix4 {
    angle:=h.time*o.spin;
    rotation:=W.Matrix4.{.[cos(angle),0,sin(angle),0],.[0,1,0,0],.[-sin(angle),0,cos(angle),0],.[0,0,0,1]};
    transform:=W.matrix4_multiply(W.matrix4_scaling(o.scale.x,o.scale.y,o.scale.z),rotation);
    return W.matrix4_multiply(transform,W.matrix4_translation(o.position.x,o.position.y,o.position.z));
}
scene_update :: () { if h.shot || h.smoke h.time=0.8; }
scene_draw :: (view: R3.View) {
    light: [112] u8;
    MAT.std140_write_vec4(light,0,.[-0.45,-1,-0.35,0]); MAT.std140_write_vec4(light,16,.[0.16,0.17,0.2,0]);
    MAT.std140_write_vec4(light,32,.[0.95,0.92,0.85,0]);
    eye:=h.camera.position; MAT.std140_write_vec4(light,48,.[eye.x,eye.y,eye.z,0]);
    F.material_stage_set_uniform(*material.Fragment,0,light);
    shadow: [320] u8; F.material_stage_set_uniform(*material.Fragment,2,shadow);
    shadow_matrix: [64] u8; MAT.std140_write_matrix(shadow_matrix,0,W.MATRIX4_IDENTITY); F.material_stage_set_uniform(*material.Vertex,1,shadow_matrix);
    lights: [1568] u8;
    MAT.std140_write_vec4(lights,0,.[1,0,0,0]); MAT.std140_write_vec4(lights,16,.[3*cos(h.time*0.9),1.4,3*sin(h.time*0.9),6]);
    MAT.std140_write_vec4(lights,272,.[1,0.55,0.2,2.5]); MAT.std140_write_vec4(lights,528,.[1,0,0,0]);
    MAT.std140_write_vec4(lights,544,.[-2.6,4,2.4,8]); MAT.std140_write_vec4(lights,800,.[0.5,0.7,1,2]);
    len:=sqrt(cast(float32) 1.13); MAT.std140_write_vec4(lights,1056,.[0.2/len,-1/len,-0.3/len,cos(cast(float32) M.PI/6)]);
    MAT.std140_write_vec4(lights,1312,.[cos(cast(float32) M.PI/12),0,0,0]); F.material_stage_set_uniform(*material.Fragment,3,lights);
    R3.queue_clear(*queue);
    for *o,i: objects { transform:=object_world(o); R3.queue_submit(*queue,i,R3.queue_view_depth(*h.camera,transform),o.color[3]<1); }
    R3.queue_sort(*queue); draws=0;
    for item: queue.items {
        if item.transparent && alpha_probe==2 continue;
        o:=*objects[item.payload]; transform:=object_world(o);
        matrices: [128] u8; MAT.std140_write_matrix(matrices,0,W.matrix4_multiply(transform,view.view_projection)); MAT.std140_write_matrix(matrices,64,transform);
        F.material_stage_set_uniform(*material.Vertex,0,matrices);
        block: [96] u8; MAT.std140_write_vec4(block,0,o.color);
        if item.transparent && alpha_probe==1 { color:=o.color; color[3]=0; MAT.std140_write_vec4(block,0,color); }
        MAT.std140_write_vec4(block,16,.[0,0,1,ifx item.transparent then 2 else 0]); MAT.std140_write_vec4(block,48,.[o.metallic,o.roughness,0,0]);
        F.material_stage_set_uniform(*material.Fragment,1,block);
        command:=F.draw_command_from_mesh(view.target,*o.mesh,material);
        command.DepthTestEnabled=true; command.DepthWriteEnabled=!item.transparent; command.CullMode=.BACK;
        command.BlendMode=MAT.BLEND_MODE_DISABLED;
        if item.transparent {
            // Standard3D outputs straight RGB; preserve coverage in the alpha channel.
            command.BlendMode=F.Blend_Mode_NonPremultiplied;
            command.BlendMode.AlphaSource=.ONE;
        }
        F.graphics_device_draw(F.App.device,command); draws+=1;
    }
    R3.grid(*h.renderer,6,1,.[1,1,1,0.12]); assert(R3.submit(*h.renderer,view)==.None);
}
scene_check :: () {
    assert(draws==5 && queue.items.count==5);
    assert(!queue.items[2].transparent && queue.items[3].transparent && queue.items[4].transparent);
    assert(queue.items[3].view_depth>=queue.items[4].view_depth);
    // A zero-alpha surface must be pixel-identical to omitting that surface.
    // This fails if this straight-alpha shader is drawn as premultiplied RGB.
    surface:=F.drawable_target_target(h.target);
    view:=R3.View.{target=surface,view_projection=W.camera3d_view_projection(*h.camera),view_matrix=W.camera3d_view(*h.camera),time=h.time};
    with_alpha:=NewArray(h.target.Width*h.target.Height,F.Color); defer free(with_alpha.data);
    without:=NewArray(with_alpha.count,F.Color); defer free(without.data);
    for probe:1..2 {
        alpha_probe=probe;
        F.graphics_device_clear(F.App.device,surface,.[F.Color.{31,38,51,255}],1,0,.COLOR | .DEPTH);
        R3.clear(*h.renderer); scene_draw(view);
        F.texture_get_data(F.target_texture(h.target),ifx probe==1 then with_alpha else without);
    }
    for pixel,i:with_alpha assert(pixel==without[i],"Zero-alpha surface changed a background pixel: %",i);
    alpha_probe=0;
    print("forward3d alpha GPU PASS\n");
}
scene_stop :: () {
    for *o: objects R3.mesh_dispose(*o.mesh); R3.queue_dispose(*queue);
    F.material_destroy(material); F.shader_dispose(vertex); F.shader_dispose(fragment); free(vertex); free(fragment);
}
