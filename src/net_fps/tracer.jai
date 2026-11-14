// Hit testing stays on the server's eye ray. Only the cosmetic tracer is offset.
tracer_segment :: (from,to:W.Vec3,cam:*W.Camera3D)->(W.Vec3,W.Vec3,bool) {
    direction:=W.camera3d_forward(cam);
    // A world-width quad touching the eye/near plane can cover half the screen.
    // Keep the cosmetic segment at least half a metre away, even after prediction moves the camera.
    near:=max(cam.near_clip+cast(float32).02,cast(float32).5);
    da:=W.v3_dot(from-cam.position,direction); db:=W.v3_dot(to-cam.position,direction);
    a:=from; b:=to;
    if da<near && db<near return a,b,false;
    if da<near a=from+(to-from)*((near-da)/(db-da));
    else if db<near b=from+(to-from)*((near-da)/(db-da));
    return a,b,W.v3_dot(b-a,b-a)>0.000001;
}
draw_tracer :: (shot:Shot) {
    from:=shot.from; me:=local_player();
    if shot.own && me!=null && me.respawn<=0 {
        fwd:=W.camera3d_forward(*camera); right:=W.camera3d_right(*camera);
        from=camera.position+fwd*.72+right*.17-W.v3_cross(right,fwd)*.13;
    }
    a,b,visible:=tracer_segment(from,shot.to,*camera); if !visible return;
    d:=b-a; length:=sqrt(W.v3_dot(d,d));
    y:=atan2(-d.x,-d.z); p:=atan2(d.y,sqrt(d.x*d.x+d.z*d.z));
    thickness:=.025*clamp(shot.life/.09,cast(float32)0,cast(float32)1)+.01;
    // Preserve the reference world-space beam, but cap its projected width near
    // the eye. Clipping its centerline alone still leaves a wide near-plane face.
    depth:=min(W.v3_dot(a-camera.position,W.camera3d_forward(*camera)),W.v3_dot(b-camera.position,W.camera3d_forward(*camera)));
    thickness=min(thickness,depth*tan(cast(float32)1.25*.5)*8/cast(float32)game_height);
    fps_box((a+b)*.5,.{thickness,thickness,max(length,cast(float32).01)},.[1,.9,.55,1],y,p,true);
}

// Keep these adversarial shots visible in every test frame, including the screenshot.
tracer_test_peak,tracer_test_visible:int;
tracer_test_draw :: () {
    origin:=camera.position; f:=W.camera3d_forward(*camera); r:=W.camera3d_right(*camera); u:=W.v3_cross(r,f);
    // Eye-origin, nearly parallel, crossing the camera, and entirely behind it.
    tests:=Shot.[.{from=origin,to=origin+f*20},
        .{from=origin-f*.02+r*.001,to=origin+f*25+r*.5},
        .{from=origin-f*2-r*2,to=origin+f*5+r*2},
        .{from=origin-f*3,to=origin-f},
        .{from=origin+f*5-r*2+u,to=origin+f*5+r*2+u}];
    for shot:tests draw_tracer(shot);
    a,b,visible:=tracer_segment(origin-f,origin-f*3,*camera); assert(!visible);
    a,b,visible=tracer_segment(origin-f,origin+f*4,*camera); assert(visible && W.v3_dot(a-origin,f)>=.4999);
    a,b,visible=tracer_segment(origin+f*4,origin-f,*camera); assert(visible && W.v3_dot(b-origin,f)>=.4999);
}
tracer_test_pixels :: () {
    image:=F.image_create(target.Width,target.Height); defer F.image_destroy(*image);
    F.texture_get_data(F.target_texture(target),image.Data);
    count:=0; for pixel:image.Data if pixel.r>245 && pixel.g>210 && pixel.g<240 && pixel.b>125 && pixel.b<155 count+=1;
    tracer_test_peak=max(tracer_test_peak,count); tracer_test_visible+=count;
    if count>=target.Width*target.Height/100 {
        png:=F.image_encode_png(image); defer free(png.data);
        _=FILE.write_entire_file("library/screenshots/tracer-failure.png",cast(string)png);
        print("tracer frame %, thickness %, camera %\n",game_frame,renderer.debug.thickness,camera.position);
    }
    assert(count<target.Width*target.Height/100,"Tracer expanded into a screen-covering polygon: % pixels",count);
}
