storage:F.Storage_Container;
materials:MAT.Material_Library; renderer:R3.Render3D; camera:W.Camera3D;
target:*F.Target; mesh:F.Mesh; material,character:*MAT.Material;
look_initialized:bool;
view_start :: () {
    level_build(); storage.Root="."; materials.storage=*storage; materials.device=F.App.device;
    files:=MAT.material_load_directory("src/net_fps/shaders/Compiled"); defer MAT.material_load_directory_free(files);
    assert(MAT.material_register_directory(*materials,files)=="");
    reason:string; material,reason=MAT.material_create(*materials,"Arena"); assert(reason==""); character,reason=MAT.material_create(*materials,"Arena"); assert(reason=="");
    assert(MAT.material_set_number(character,"Arena_main","grid",.[0,0,0,0]));
    glow,reason=MAT.material_create(*materials,"Arena"); assert(reason=="");
    assert(MAT.material_set_number(glow,"Arena_main","grid",.[0,0,0,0]));
    assert(MAT.material_set_number(glow,"Arena_main","emissive",.[1,0,0,0]));
    assert(R3.init(*renderer,*materials)==""); renderer.debug.thickness=.003;
    p:=cube(); defer primitive_free(*p); assert(R3.mesh_upload(*mesh,F.App.device,*p)); W.camera3d_init(*camera,1280,720); W.camera3d_set_field_of_view(*camera,1.25);
}
view_stop :: () {
    F.window_set_mouse_relative_mode(F.App.window,false); R3.dispose(*renderer); R3.mesh_dispose(*mesh); MAT.material_library_dispose(*materials);
    if target!=null { F.target_dispose(target); free(target); } array_free(level); array_free(shots); array_free(view.remotes); array_free(view.feed);
}
local_player :: ()->*Player {
    if !client return null; obj,ok:=O.find_owned(*client_reg,sess.client_server_id); if !ok return null; return O.component_data(obj,Player,1);
}
game_update :: (dt:float32) {
    if has_arg("menu-test") && game_frame==8 menu_join=false;
    keys:=F.input_keyboard(F.App.input); mouse:=F.input_mouse(F.App.input);
    if !F.window_focused(F.App.window) { mouse_look=false; F.window_set_mouse_relative_mode(F.App.window,false); }
    if !game_text_captured && F.keyboard_pressed(keys,.ESCAPE) {
        if mouse_look { mouse_look=false; F.window_set_mouse_relative_mode(F.App.window,false); }
        else if running { net_stop(); look_initialized=false; } else F.app_exit();
    }
    input_bits=0;
    if running && !game_text_captured && !game_capture.keyboard && F.window_focused(F.App.window) {
        if !game_capture.pointer && F.mouse_pressed(mouse,.LEFT) && !mouse_look && !game_shot && !game_smoke { mouse_look=true; F.window_set_mouse_relative_mode(F.App.window,true); }
        if mouse_look { yaw-=mouse.Delta.x*.0025; pitch=clamp(pitch-mouse.Delta.y*.0025,-1.55,1.55); }
        input_bits=0; if F.keyboard_down(keys,.W) input_bits|=1; if F.keyboard_down(keys,.S) input_bits|=2; if F.keyboard_down(keys,.A) input_bits|=4; if F.keyboard_down(keys,.D) input_bits|=8;
        if F.keyboard_pressed(keys,.SPACE) jump_seq=cast,trunc(u8)(cast(u16)jump_seq+1);
    }
    voice_controls(dt);
    if running {
        voice_update(dt);
        p:=local_player(); if p!=null && !look_initialized { yaw=p.yaw; pitch=p.pitch; look_initialized=true; }
        fire_timer=max(cast(float32)0,fire_timer-dt);
        if p!=null && p.respawn<=0 && fire_timer<=0 && ((!game_capture.pointer && !game_capture.keyboard && mouse_look && F.mouse_down(mouse,.LEFT)) || (game_smoke && !has_arg("menu-test"))) {
            obj,ok:=O.find_owned(*client_reg,sess.client_server_id); if ok _=RPC.send_with(*runtime.client.rpc,1,obj.id,.Server,write_fire,null); fire_timer=.16;
        }
        carry+=min(dt,cast(float32).1)*1000; ms:=cast(int)carry; carry-=cast(float32)ms; if ms>0 _=N.update(*runtime,ms);
        for *shot:shots shot.life-=dt; i:=shots.count-1; while i>=0 { if shots[i].life<=0 { shots[i]=shots[shots.count-1]; shots.count-=1; }; i-=1; }
        kill_time=max(cast(float32)0,kill_time-dt);
        frame_limit:=arg_int("frames=",0); if frame_limit>0 && game_frame>=frame_limit F.app_exit();
    }
}
draw_box :: (pos,size:W.Vec3,tint:[4]float32,mat:*MAT.Material) {
    transform:=W.matrix4_multiply(W.matrix4_scaling(size.x,size.y,size.z),W.matrix4_translation(pos.x,pos.y,pos.z));
    items:=R3.Model_Item.[.{world=transform,tint=tint}]; assert(R3.models(*renderer,*mesh,mat,items)==.None);
}
draw_scene :: () {
    width:=game_width; height:=game_height;
    if target==null || target.Width!=width || target.Height!=height { if target!=null { F.target_dispose(target); free(target); } target=F.target_create_formats(F.App.device,width,height,.[.COLOR,.DEPTH32]); }
    p:=local_player(); pos:=W.Vec3.{sin(view.time*.12)*22,11,cos(view.time*.12)*22}; focus:=W.Vec3.{0,1,0};
    if p!=null && !has_arg("overview") { pos=eye(p.pos); focus=pos+look(yaw,pitch); }
    if has_arg("tracer-test") { pos=.{0,1.6,10}; focus=pos+look(cast(float32)(game_frame%5)*.17,cast(float32)(game_frame%3-1)*.7); }
    W.camera3d_set_viewport(*camera,width,height); W.camera3d_set_position(*camera,pos); W.camera3d_set_target(*camera,focus); W.camera3d_set_far_clip(*camera,150);
    surface:=F.drawable_target_target(target); F.graphics_device_clear(F.App.device,surface,.[F.Color.{158,184,214,255}],1,0,.COLOR|.DEPTH); R3.clear(*renderer);
    for box:level draw_box((box.lo+box.hi)*.5,box.hi-box.lo,box.tint,material);
    fps_actors(pos,yaw,pitch,p!=null && p.respawn<=0 && !has_arg("overview"));
    for shot:shots draw_tracer(shot);
    if has_arg("tracer-test") tracer_test_draw();
    assert(R3.submit(*renderer,.{target=surface,view_projection=W.camera3d_view_projection(*camera),view_matrix=W.camera3d_view(*camera)})==.None);
    if has_arg("tracer-test") tracer_test_pixels();
    assert(G2.texture(*game_canvas,F.target_texture(target),F.Matrix3x2_Identity)==.None);
 }

game_draw :: () {
    if has_arg("tracer-test") { draw_scene(); return; }
    if !running { arena_menu(); return; }
    draw_scene(); fps_hud();
}

game_ready :: ()->bool { if has_arg("menu") || has_arg("tracer-test") return true; return running && game_frame>240 && (ifx client then local_player()!=null && !client_sim.needs_full else ticks>30); }
game_check :: () {
    if has_arg("tracer-test") { assert(tracer_test_visible>10); print("tracer: 60 GPU frames, worst coverage % pixels\n",tracer_test_peak); return; }
    if has_arg("menu") return;
    if has_arg("menu-test") assert(menu_input_checks==4);
    assert(level.count==38); p:=local_player(); if client { assert(p!=null && p.health>=0 && p.health<=100); assert(!client_sim.needs_full); }
    // Exercise collision, jump, and the authoritative head-hit/respawn path independently of bots.
    probe:=Player.{pos=.{-18,0,-18},grounded=true}; player_move(*probe,1,true,.02); assert(probe.pos.y>0);
    probe.pos=.{-19.5,0,-19.5}; for i:0..200 player_move(*probe,1,false,.02); assert(probe.pos.z>=-19.651);
    if server { assert(ticks>0); }
    if has_arg("voicetest") { print("Voice ready % status % sent % rx % peak %\n",voice_ready,voice_status,voice_sent,voice_received,voice_max_peak); assert(voice_ready && voice_sent>10 && voice_received>10 && voice_max_peak>.001,"Opus network loopback produced no decoded audio"); print("Voice loopback PASS: sent %, received %, decoded peak %\n",voice_sent,voice_received,voice_max_peak); }
    print("net_fps: % server ticks, % replicated players, % shot RPCs\n",ticks,client_reg.active_count,received_shots);
}
