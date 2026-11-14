Collision_Box :: struct { center,half,axis_x,axis_z:W.Vec3; }
Player :: struct { pos,vel:W.Vec3; yaw,gait,coyote,jump_buffer:float32; grounded:bool; }
Player_Input :: struct { x,y:float32; sprint,jump:bool; }
Rig :: struct { yaw:float32; pitch:float32=.38; distance:float32=7.5; boom:float32=7.5; lift:float32; focus:W.Vec3; }
player:Player; rig:Rig; colliders:[..]Collision_Box;
box_local :: (box:Collision_Box,v:W.Vec3)->W.Vec3 { return .{dot(v,box.axis_x),v.y,dot(v,box.axis_z)}; }
box_contact :: (box:Collision_Box,pos:W.Vec3,radius:float32)->W.Vec3,float32 {
    p:=box_local(box,pos-box.center); dx:=p.x-clamp(p.x,-box.half.x,box.half.x); dz:=p.z-clamp(p.z,-box.half.z,box.half.z); d2:=dx*dx+dz*dz;
    if d2>=radius*radius return .{},0;
    if d2>.0000001 { d:=sqrt(d2); return (box.axis_x*dx+box.axis_z*dz)*(1/d),radius-d; }
    x:=box.half.x-abs(p.x); z:=box.half.z-abs(p.z);
    if x<z return box.axis_x*(ifx p.x<0 then cast(float32)-1 else 1),radius+x;
    return box.axis_z*(ifx p.z<0 then cast(float32)-1 else 1),radius+z;
}
player_clear :: (pos:W.Vec3)->bool {
    if pos.y<terrain_height(pos.x,pos.z)-.005 return false;
    for b:colliders { if pos.y>=b.center.y+b.half.y-.001 || pos.y+1.78<=b.center.y-b.half.y+.001 continue; _,depth:=box_contact(b,pos,.38); if depth>.001 return false; } return true;
}
player_step :: (input:Player_Input,dt:float32) {
    p:=*player; p.coyote=ifx p.grounded then .1 else max(cast(float32)0,p.coyote-dt);
    if p.jump_buffer>0 && p.coyote>0 { p.vel.y=9; p.grounded=false; p.jump_buffer=0; p.coyote=0; } p.jump_buffer=max(cast(float32)0,p.jump_buffer-dt);
    x:=input.x; y:=input.y; len:=sqrt(x*x+y*y); if len>1 { x/=len; y/=len; }
    dir:=W.Vec3.{cos(rig.yaw)*x-sin(rig.yaw)*y,0,-sin(rig.yaw)*x-cos(rig.yaw)*y}; speed:float32=ifx input.sprint then 6.5 else 4.2;
    horizontal:=W.Vec3.{p.vel.x,0,p.vel.z}; change:=dir*speed-horizontal; acceleration:float32=ifx p.grounded then 38 else 14;
    len=length(change); if len>acceleration*dt change=change*(acceleration*dt/len); horizontal+=change; p.vel.x=horizontal.x; p.vel.z=horizontal.z;
    if length(dir)>.01 { target:=atan2(dir.x,-dir.z); delta:=atan2(sin(target-p.yaw),cos(target-p.yaw)); p.yaw+=delta*(1-exp(-18*dt)); }
    previous:=p.pos; follow_ground:=p.grounded && p.vel.y<=0 && abs(previous.y-terrain_height(previous.x,previous.z))<.04;
    p.pos+=horizontal*dt; if follow_ground p.pos.y=max(p.pos.y,terrain_height(p.pos.x,p.pos.z));
    for iter:0..3 for b:colliders {
        top:=b.center.y+b.half.y; bottom:=b.center.y-b.half.y; if p.pos.y>=top-.001 || p.pos.y+1.78<=bottom+.001 continue;
        normal,depth:=box_contact(b,p.pos,.38); if depth<=0 continue; step_pos:=p.pos; step_pos.y=top;
        if p.grounded && top-p.pos.y<=.30 && player_clear(step_pos) { p.pos=step_pos; continue; }
        p.pos+=normal*(depth+.0001); into:=dot(p.vel,normal); if into<0 p.vel-=normal*into;
    }
    old_y:=p.pos.y; p.vel.y-=22*dt; next_y:=old_y+p.vel.y*dt; p.grounded=false;
    for b:colliders {
        _,depth:=box_contact(b,p.pos,.378); if depth<=0 continue; top:=b.center.y+b.half.y; bottom:=b.center.y-b.half.y;
        if p.vel.y<=0 && old_y>=top-.001 && next_y<=top { next_y=top; p.vel.y=0; p.grounded=true; }
        else if p.vel.y>0 && old_y+1.78<=bottom+.001 && next_y+1.78>=bottom { next_y=bottom-1.78; p.vel.y=0; }
    }
    floor_y:=terrain_height(p.pos.x,p.pos.z); if next_y<=floor_y || (follow_ground && p.vel.y<=0 && old_y-floor_y<.15) { next_y=floor_y; p.vel.y=0; p.grounded=true; }
    p.pos.y=next_y; p.pos.x=clamp(p.pos.x,-110,110); p.pos.z=clamp(p.pos.z,-110,110);
    if p.grounded { delta:=p.pos-previous; p.gait+=sqrt(delta.x*delta.x+delta.z*delta.z)*10; }
}
camera_fraction :: (start,finish:W.Vec3,padding:float32)->float32 {
    fraction:float32=1; delta:=finish-start;
    if min(start.y,finish.y)<padding {
        steps:=max(1,cast(int)ceil(length(delta)/.1));
        for i:0..steps { t:=cast(float32)i/cast(float32)steps; p:=start+delta*t;
            if p.y<terrain_height(p.x,p.z)+padding { lo:=max(cast(float32)0,cast(float32)(i-1)/cast(float32)steps); hi:=t;
                for j:0..7 { mid:=(lo+hi)*.5; q:=start+delta*mid; if q.y<terrain_height(q.x,q.z)+padding hi=mid; else lo=mid; }
                fraction=lo; break;
            }
        }
    }
    for b:colliders {
        origin:=box_local(b,start-b.center); delta:=box_local(b,finish-start); half:=b.half+W.Vec3.{padding,padding,padding}; enter:float32=0; leave:float32=1;
        for axis:0..2 { o:=(cast(*float32)*origin)[axis]; d:=(cast(*float32)*delta)[axis]; h:=(cast(*float32)*half)[axis];
            if abs(d)<.000001 { if abs(o)>h { leave=-1; break; } }
            else { a:=(-h-o)/d; z:=(h-o)/d; enter=max(enter,min(a,z)); leave=min(leave,max(a,z)); }
        } if enter<=leave && leave>=0 fraction=min(fraction,enter);
    } return fraction;
}
camera_clear :: (pos:W.Vec3,padding:float32)->bool { return camera_fraction(pos,pos,padding)==1; }
fit_distance :: (focus,axis:W.Vec3,requested,padding:float32)->float32 {
    if camera_clear(focus+axis*requested,padding) return requested; steps:=max(1,cast(int)ceil(requested/.1)); blocked:=requested;
    for i:1..steps { candidate:=max(cast(float32).02,requested-cast(float32)i*.1);
        if camera_clear(focus+axis*candidate,padding) { clear:=candidate; for j:0..7 { mid:=(clear+blocked)*.5; if camera_clear(focus+axis*mid,padding) clear=mid; else blocked=mid; } return max(cast(float32).02,clear-.01); } blocked=candidate;
    } return .02;
}
follow_camera :: (dt:float32,snap:bool=false) {
    target:=player.pos+W.Vec3.{0,1.05,0}; weight:=ifx snap then cast(float32)1 else 1-exp(-12*dt); rig.focus+=(target-rig.focus)*weight;
    if camera_fraction(target,rig.focus,.08)<1 rig.focus=target; rig.focus.y=max(rig.focus.y,player.pos.y+.65);
    padding:=.15+camera.near_clip*tan(camera.field_of_view*.5)*sqrt(1+camera.aspect_ratio*camera.aspect_ratio); requested_lift:float32; auto_pitch:=max(rig.pitch,cast(float32)1.1);
    for attempt:0..10 { angle:=rig.pitch+(auto_pitch-rig.pitch)*cast(float32)attempt/10; axis:=W.Vec3.{sin(rig.yaw)*cos(angle),sin(angle),cos(rig.yaw)*cos(angle)};
        if camera_fraction(rig.focus,rig.focus+axis*rig.distance,padding)==1 { requested_lift=angle-rig.pitch; break; }
    }
    rig.lift+=(requested_lift-rig.lift)*(ifx snap then cast(float32)1 else 1-exp(-10*dt)); angle:=min(rig.pitch+rig.lift,cast(float32)1.35); axis:=W.Vec3.{sin(rig.yaw)*cos(angle),sin(angle),cos(rig.yaw)*cos(angle)}; allowed:=fit_distance(rig.focus,axis,rig.distance,padding);
    if allowed<min(rig.distance,cast(float32)3) for attempt:1..10 {
        candidate:=angle+(1.35-angle)*cast(float32)attempt/10; direction:=W.Vec3.{sin(rig.yaw)*cos(candidate),sin(candidate),cos(rig.yaw)*cos(candidate)}; distance:=fit_distance(rig.focus,direction,rig.distance,padding);
        if distance>allowed { axis=direction; allowed=distance; rig.lift=candidate-rig.pitch; } if allowed>=min(rig.distance,cast(float32)3) break;
    }
    if snap || allowed<rig.boom rig.boom=allowed; else rig.boom+=(allowed-rig.boom)*(1-exp(-5*dt)); rig.boom=fit_distance(rig.focus,axis,rig.boom,padding);
    W.camera3d_set_target(*camera,rig.focus); W.camera3d_set_position(*camera,rig.focus+axis*rig.boom);
}
reset_player :: () { player=.{pos=.{0,0,4.8},grounded=true}; rig=.{}; accumulator=0; follow_camera(0,true); }
