#load "../../shared/game_host.jai";
M :: #import "Math"; using M;
W :: #import "kit/world";
DA :: #import "core/dasset";
MAT :: #import "kit/rendering/material";
R3 :: #import "kit/rendering/3d";
R2 :: #import "kit/rendering/2d";
#load "../../shared/geometry3d.jai";
#load "scenery.jai";
#load "controller.jai";
storage:F.Storage_Container; materials:MAT.Material_Library; renderer:R3.Render3D; batch:R2.Render2D;
toon,ground,hero,sky,coin,blob,edge,ao,sun,water,flower_mat:*MAT.Material;
meshes:[6]F.Mesh; ball,card,terrain,water_mesh:F.Mesh;
scene,post,minimap,shadow,reflection,final_target:*F.Target;
camera,map_camera,reflection_camera:W.Camera3D; light_view,light_projection,reflection_projection:W.Matrix4;
time,accumulator:float32; paused,no_ao,no_shadow,no_edge,no_reflection:bool;
draws,static_count:int;
main :: () { game_run("stylized3d"); }
make_material :: (name:string)->*MAT.Material { m,reason:=MAT.material_create(*materials,name); assert(reason=="","%: %",name,reason); return m; }
game_start :: () {
    storage.Root="."; materials.storage=*storage; materials.device=F.App.device;
    files:=MAT.material_load_directory("src/stylized3d/shaders/Compiled"); defer MAT.material_load_directory_free(files); assert(MAT.material_register_directory(*materials,files)=="");
    toon=make_material("Toon"); ground=make_material("Toon"); flower_mat=make_material("Toon"); hero=make_material("Hero"); sky=make_material("Sky"); coin=make_material("Billboard"); blob=make_material("Blob"); edge=make_material("DepthEdge"); ao=make_material("AmbientOcclusion"); sun=make_material("SunShadow"); water=make_material("Water");
    assert(MAT.material_set_number(ground,"Toon_scene","color",.[.52,.64,.30,1])); assert(MAT.material_set_number(ground,"Toon_scene","terrain",.[1,0,0,0])); assert(MAT.material_set_number(flower_mat,"Toon_scene","flower",.[1,0,0,0]));
    assert(MAT.material_set_number(edge,"DepthEdge_edge","clip",.[.1,140,0,0])); assert(MAT.material_set_number(ao,"AmbientOcclusion_ao","clip",.[.1,140,0,0])); assert(MAT.material_set_number(ao,"AmbientOcclusion_ao","strength",.[1.15,0,0,0])); assert(MAT.material_set_number(ao,"AmbientOcclusion_ao","radius",.[.65,0,0,0]));
    assert(R3.init(*renderer,*materials)==""); assert(R2.init(*batch,*materials)=="");
    upload(*meshes[0],cube()); upload(*meshes[1],faceted(true)); upload(*meshes[2],faceted(false)); upload(*meshes[3],trunk_mesh()); upload(*meshes[4],grass_mesh()); upload(*meshes[5],flower_mesh());
    upload(*ball,sphere(24,32)); upload(*card,quad()); upload(*terrain,terrain_mesh()); p:=quad(); for *v:p.vertices { v.position=.[v.position[0]*2,0,v.position[1]*2]; v.normal=.[0,1,0]; } upload(*water_mesh,p);
    shadow=F.target_create_formats(F.App.device,2048,2048,.[.COLOR,.DEPTH32]); minimap=F.target_create_formats(F.App.device,180,180,.[.COLOR,.DEPTH32]);
    for m:*MAT.Material.[toon,ground,flower_mat] assert(MAT.material_set_texture(m,"Toon_scene","sunDepth",shadow.Attachments[1])); assert(MAT.material_set_texture(hero,"Hero_body","sunDepth",shadow.Attachments[1]));
    W.camera3d_init(*camera,640,360); W.camera3d_set_far_clip(*camera,140); W.camera3d_init(*map_camera,180,180); W.camera3d_set_position(*map_camera,.{0,30,1}); W.camera3d_set_target(*map_camera,.{});
    scenery_build(); reset_player(); no_ao=has_arg("noao"); no_edge=has_arg("flat"); no_shadow=has_arg("noshadow"); no_reflection=has_arg("noreflection");
    if game_shot { player.pos=.{0,0,.35}; rig.yaw=-.2; rig.pitch=.38; rig.distance=10; if has_arg("water-shot") { player.pos=.{-4,0,6}; rig.yaw=.7; rig.distance=12; } }
}
upload :: (mesh:*F.Mesh,p:DA.Dasset_Primitive) { assert(R3.mesh_upload(mesh,F.App.device,*p)); primitive_free(*p); }
place :: (pos,size:W.Vec3,yaw:float32=0)->W.Matrix4 {
    rotation:=W.Matrix4.{.[cos(yaw),0,sin(yaw),0],.[0,1,0,0],.[-sin(yaw),0,cos(yaw),0],.[0,0,0,1]};
    return W.matrix4_multiply(W.matrix4_multiply(W.matrix4_scaling(size.x,size.y,size.z),rotation),W.matrix4_translation(pos.x,pos.y,pos.z));
}
game_update :: (dt:float32) {
    keys:=F.input_keyboard(F.App.input); mouse:=F.input_mouse(F.App.input);
    if game_text_captured || game_capture.keyboard || (!F.window_focused(F.App.window) && !game_smoke && !game_shot) return;
    if F.keyboard_pressed(keys,.ESCAPE) F.app_exit(); if F.keyboard_pressed(keys,.R) reset_player(); if F.keyboard_pressed(keys,.P) paused=!paused;
    if F.keyboard_pressed(keys,.O) no_ao=!no_ao; if F.keyboard_pressed(keys,.E) no_edge=!no_edge; if F.keyboard_pressed(keys,.L) no_shadow=!no_shadow;
    if F.mouse_down(mouse,.RIGHT) { rig.yaw-=mouse.Delta.x*.006; rig.pitch=clamp(rig.pitch+mouse.Delta.y*.006,.05,1.25); }
    rig.distance=clamp(rig.distance*pow(cast(float32).88,mouse.WheelValue.y),3,24);
    if paused return; dt=min(dt,cast(float32).05); time+=dt;
    input:=Player_Input.{}; if F.keyboard_down(keys,.W) input.y+=1; if F.keyboard_down(keys,.S) input.y-=1; if F.keyboard_down(keys,.A) input.x-=1; if F.keyboard_down(keys,.D) input.x+=1;
    input.sprint=F.keyboard_down(keys,.LEFT_SHIFT); input.jump=F.keyboard_pressed(keys,.SPACE);
    if game_smoke { input.y=ifx game_frame<70 then 1 else 0; input.x=ifx game_frame>=70 && game_frame<100 then 1 else 0; input.sprint=true; input.jump=game_frame==20; }
    if input.jump player.jump_buffer=.12;
    accumulator+=dt; while accumulator>=1.0/120 { player_step(input,1.0/120); accumulator-=1.0/120; }
    if game_shot time=4.9;
    follow_camera(dt);
}
resize_target :: (target:**F.Target,width,height:s32,depth:bool=true) {
    if target.*!=null && target.*.Width==width && target.*.Height==height return;
    if target.*!=null { F.target_dispose(target.*); free(target.*); }
    target.*=ifx depth then F.target_create_formats(F.App.device,width,height,.[.COLOR,.DEPTH32]) else F.target_create(F.App.device,width,height);
}
view_globals :: (cam:*W.Camera3D,fog:float32,clip:bool=false)->[272]u8 {
    data:[272]u8; sun_dir:=normalize(W.Vec3.{-.6,-1,.4}); right:=W.camera3d_right(cam); up:=cross(right,W.camera3d_forward(cam));
    MAT.std140_write_vec4(data,0,.[sun_dir.x,sun_dir.y,sun_dir.z,0]); MAT.std140_write_vec4(data,16,.[1,.95,.82,1]); MAT.std140_write_vec4(data,32,.[.24,.27,.39,.55]);
    MAT.std140_write_vec4(data,48,.[.91,.89,.73,1]); MAT.std140_write_vec4(data,64,.[16,75,fog,0]); MAT.std140_write_vec4(data,80,.[right.x,right.y,right.z,0]); MAT.std140_write_vec4(data,96,.[up.x,up.y,up.z,0]);
    MAT.std140_write_matrix(data,112,light_projection); MAT.std140_write_vec4(data,176,.[1.0/2048,.00045,.85,ifx no_shadow then 0 else 1]);
    MAT.std140_write_matrix(data,192,reflection_projection); MAT.std140_write_vec4(data,256,.[-.38,cast(float32)clip,fog,ifx no_reflection then 0 else 1]); return data;
}
submit :: (view:R3.View,pass:string) { assert(R3.submit(*renderer,view,pass)==.None,"Pass % failed",pass); draws+=renderer.draw_calls; }
record :: () {
    R3.clear(*renderer); assert(R3.model(*renderer,*ball,sky,place(camera.position,.{80,80,80}))==.None);
    assert(R3.model(*renderer,*terrain,ground,W.MATRIX4_IDENTITY)==.None);
    for *b,i:scenery {
        mat:=ifx i==5 then flower_mat else toon;
        assert(R3.buffer(*renderer,*meshes[i],mat,*b.buffer,b.items.count)==.None);
        if i<4 assert(R3.buffer(*renderer,*meshes[i],sun,*b.buffer,b.items.count)==.None);
    }
    record_player(); assert(R3.model(*renderer,*water_mesh,water,place(.{-4.7,-.38,4},.{3.1,1,2.8}))==.None);
    coins:[9]R3.Model_Item; blobs:[10]R3.Model_Item;
    for *item,i:coins {
        x:=-4.8+cast(float32)i*1.2; z:float32=ifx i%3==0 then -2.2 else 3;
        item.*=.{world=place(.{x,.95+.12*sin(time*2+cast(float32)i),z},.{.5,.5,.5}),tint=.[1,.78,.24,1]};
        blobs[i]=.{world=place(.{x,terrain_height(x,z)+.02,z},.{.34,1,.34}),tint=.[1,1,1,.35]};
    }
    support:=terrain_height(player.pos.x,player.pos.z); for b:colliders { local:=box_local(b,player.pos-b.center); top:=b.center.y+b.half.y; if abs(local.x)<=b.half.x && abs(local.z)<=b.half.z && top<=player.pos.y+.01 support=max(support,top); }
    blobs[9]=.{world=place(.{player.pos.x,support+.02,player.pos.z},.{.55,1,.55}),tint=.[1,1,1,.55/(1+(player.pos.y-support)*.5)]};
    assert(R3.models(*renderer,*card,coin,coins)==.None); assert(R3.models(*renderer,*card,blob,blobs)==.None);
}
post_process :: (mat:*MAT.Material) {
    R2.reset(*batch); assert(R2.texture(*batch,F.target_texture(scene),F.Matrix3x2_Identity,material=mat)==.None); assert(R2.submit(*batch,.{target=F.drawable_target_target(post),time=time})==.None);
    R2.reset(*batch); assert(R2.texture(*batch,F.target_texture(post),F.Matrix3x2_Identity)==.None); assert(R2.submit(*batch,.{target=F.drawable_target_target(scene),time=time})==.None);
}
render_scene :: (width,height:s32) {
    scale:=max(cast(s32)1,height/360); sw:=(width+scale-1)/scale; sh:=(height+scale-1)/scale;
    resize_target(*scene,sw,sh); resize_target(*post,sw,sh,false); resize_target(*reflection,sw,sh); resize_target(*final_target,width,height,false);
    W.camera3d_set_viewport(*camera,sw,sh);
    assert(MAT.material_set_texture(water,"Water_water","reflection",F.target_texture(reflection)));
    assert(MAT.material_set_texture(edge,"DepthEdge_edge","depth",scene.Attachments[1])); assert(MAT.material_set_texture(ao,"AmbientOcclusion_ao","depth",scene.Attachments[1]));
    assert(MAT.material_set_number(edge,"DepthEdge_edge","texel",.[1/cast(float32)sw,1/cast(float32)sh,0,0])); assert(MAT.material_set_number(ao,"AmbientOcclusion_ao","texel",.[1/cast(float32)sw,1/cast(float32)sh,0,0]));
    tan_half:=tan(camera.field_of_view*.5); assert(MAT.material_set_number(ao,"AmbientOcclusion_ao","projection",.[tan_half*cast(float32)sw/cast(float32)sh,tan_half,0,0])); assert(MAT.material_set_number(ao,"AmbientOcclusion_ao","fog",.[16,75,0,0]));
    focus:=player.pos; focus.y=0; light:=normalize(W.Vec3.{-.6,-1,.4}); light_view=W.matrix4_look_at(focus-light*40,focus,.{0,1,0}); ortho,_:=W.matrix4_orthographic(48,48,1,85); light_projection=W.matrix4_multiply(light_view,ortho);
    reflection_camera=camera; reflection_camera.position.y=-.76-camera.position.y; reflection_camera.target.y=-.76-camera.target.y; reflection_camera.dirty=true; reflection_projection=W.camera3d_view_projection(*reflection_camera);
    record(); draws=0;
    if !no_shadow { surface:=F.drawable_target_target(shadow); F.graphics_device_clear(F.App.device,surface,.[F.Color_White],1,0,.COLOR|.DEPTH); submit(.{target=surface,view_projection=light_projection,view_matrix=light_view,time=time},"shadow"); }
    if !no_reflection {
        surface:=F.drawable_target_target(reflection); F.graphics_device_clear(F.App.device,surface,.[F.Color.{232,227,186,255}],1,0,.COLOR|.DEPTH);
        globals:=view_globals(*reflection_camera,1,true); view:=R3.View.{target=surface,view_projection=reflection_projection,view_matrix=W.camera3d_view(*reflection_camera),globals=globals,time=time}; for pass:string.["sky","scene","body"] submit(view,pass);
    }
    surface:=F.drawable_target_target(scene); F.graphics_device_clear(F.App.device,surface,.[F.Color.{232,227,186,255}],1,0,.COLOR|.DEPTH);
    globals:=view_globals(*camera,1); view:=R3.View.{target=surface,view_projection=W.camera3d_view_projection(*camera),view_matrix=W.camera3d_view(*camera),globals=globals,time=time};
    for pass:string.["sky","scene","silhouette","body"] submit(view,pass); if !no_ao post_process(ao); if !no_edge post_process(edge); submit(view,"water"); submit(view,"transparent");
    surface=F.drawable_target_target(minimap); F.graphics_device_clear(F.App.device,surface,.[F.Color.{40,48,70,255}],1,0,.COLOR|.DEPTH);
    globals=view_globals(*map_camera,0); view=.{target=surface,view_projection=W.camera3d_view_projection(*map_camera),view_matrix=W.camera3d_view(*map_camera),globals=globals,time=time}; for pass:string.["scene","body","water","transparent"] submit(view,pass);
    R2.reset(*batch); R2.push_sampler(*batch,F.texture_sampler_make(.NEAREST,.CLAMP));
    _=R2.quad_texture(*batch,F.target_texture(scene),.{0,0},.{cast(float32)width,0},.{cast(float32)width,cast(float32)height},.{0,cast(float32)height},.{0,0},.{1,0},.{1,1},.{0,1}); R2.pop_sampler(*batch);
    _=R2.rect(*batch,.{cast(float32)width-200,14,186,186},.{240,236,226,255}); _=R2.texture(*batch,F.target_texture(minimap),F.matrix3x2_create_translation(cast(float32)width-197,17));
    assert(R2.submit(*batch,.{target=F.drawable_target_target(final_target)})==.None);
}
game_draw :: () {
    render_scene(game_width,game_height);
    assert(G2.texture(*game_canvas,F.target_texture(final_target),F.Matrix3x2_Identity)==.None);
    CLAY.UI(game_panel("meadow-hud",20,20,min(cast(float32)430,game_ui.width-240)),#code {
        game_label("STYLIZED MEADOW",24,game_theme.accent);
        game_label(ifx paused then "PAUSED" else "EXPLORE THE MEADOW",14);
    });
    CLAY.UI(game_panel("meadow-controls",20,game_ui.height-110,min(cast(float32)600,game_ui.width-40)),#code {
        game_label("WASD move / Shift sprint / Space jump / RMB orbit",15);
        game_label("Wheel zoom / R reset / P pause",14,game_theme.text_dim);
        game_label(tprint("O: AO %   /   E: edges %   /   L: shadows %",!no_ao,!no_edge,!no_shadow),14,game_theme.text_dim);
    });
}
game_test_input :: () {}
game_ready :: ()->bool { return game_frame>=130; }
game_check :: () { assert(static_count>700 && draws>10); assert(player_clear(player.pos)); assert(camera_clear(camera.position,.1)); assert(abs(terrain_height(-4.7,4)+.95)<.0001); print("stylized3d: % resident instances, % draws, player %, camera %\n",static_count,draws,player.pos,camera.position); }
game_stop :: () {
    R3.dispose(*renderer); R2.dispose(*batch); for *s:scenery { R3.model_buffer_dispose(*s.buffer); array_free(s.items); } MAT.material_library_dispose(*materials);
    for *mesh:meshes R3.mesh_dispose(mesh); for mesh:*F.Mesh.[*ball,*card,*terrain,*water_mesh] R3.mesh_dispose(mesh);
    for target:*F.Target.[scene,post,minimap,shadow,reflection,final_target] if target!=null { F.target_dispose(target); free(target); } array_free(colliders);
}
