// Translated from olib_sample/net_fps/view.odin; presentation never writes simulation state.
Remote :: struct { id:O.Network_Id; pos:W.Vec3; health:s32; flash:float32; seen:bool; }
Feed :: struct { killer,victim:s32; head:bool; life:float32; }
FPS_View :: struct { remotes:[..]Remote; feed:[..]Feed; time,muzzle,kick,spread,hitmarker,damage_flash:float32; hit_head:bool; last_health:s32=100; label_id:int; }
view:FPS_View;
glow:*MAT.Material;
fps_view_reset :: () { view.remotes.count=0; view.feed.count=0; shots.count=0; view.muzzle=0; view.kick=0; view.spread=0; view.hitmarker=0; view.damage_flash=0; view.last_health=100; }
fps_view_update :: (dt:float32) {
    view.time+=dt; if !running return;
    reg:=ifx client then *client_reg else *server_reg; me:=local_player();
    for *r:view.remotes r.seen=false;
    for obj,id:reg.objects {
        p:=O.component_data(obj,Player,1); if p==null || (p==me && !has_arg("overview")) continue;
        r:*Remote; for *it:view.remotes if it.id==id { r=it; break; }
        if r==null { array_add(*view.remotes,Remote.{id=id,pos=p.pos,health=p.health}); r=*view.remotes[view.remotes.count-1]; }
        r.seen=true; r.pos=r.pos+(p.pos-r.pos)*(1-exp(-20*dt)); d:=r.pos-p.pos;
        if d.x*d.x+d.y*d.y+d.z*d.z>9 r.pos=p.pos;
        if p.health<r.health r.flash=1; r.health=p.health; r.flash=max(cast(float32)0,r.flash-dt*8);
    }
    i:=view.remotes.count-1; while i>=0 { if !view.remotes[i].seen array_unordered_remove_by_index(*view.remotes,i); i-=1; }
    if me!=null { if me.health<view.last_health view.damage_flash=1; view.last_health=me.health; }
    i=view.feed.count-1; while i>=0 { view.feed[i].life-=dt; if view.feed[i].life<=0 array_ordered_remove_by_index(*view.feed,i); i-=1; }
    view.muzzle=max(cast(float32)0,view.muzzle-dt*18); view.kick=max(cast(float32)0,view.kick-dt*10);
    view.spread=max(cast(float32)0,view.spread-dt*3); view.hitmarker=max(cast(float32)0,view.hitmarker-dt*4); view.damage_flash=max(cast(float32)0,view.damage_flash-dt*2.5);
}
fps_place :: (center,size:W.Vec3,y:float32=0,p:float32=0)->W.Matrix4 {
    m:=W.matrix4_scaling(size.x,size.y,size.z);
    if p!=0 m=W.matrix4_multiply(m,W.matrix4_from_quaternion(.[sin(-p*.5),0,0,cos(p*.5)]));
    if y!=0 m=W.matrix4_multiply(m,W.matrix4_from_quaternion(.[0,sin(-y*.5),0,cos(y*.5)]));
    return W.matrix4_multiply(m,W.matrix4_translation(center.x,center.y,center.z));
}
fps_box :: (center,size:W.Vec3,tint:[4]float32,y:float32=0,p:float32=0,emissive:bool=false) {
    item:=R3.Model_Item.[.{world=fps_place(center,size,y,p),tint=tint}];
    assert(R3.models(*renderer,*mesh,ifx emissive then glow else character,item)==.None);
}
fps_actors :: (eye_position:W.Vec3,cy,cp:float32,alive:bool) {
    reg:=ifx client then *client_reg else *server_reg;
    for r:view.remotes {
        obj,ok:=O.get(reg,r.id); if !ok continue; p:=O.component_data(obj,Player,1); if p==null || p.respawn>0 continue;
        c:=slot_color(p.slot); tint:=float32.[cast(float32)c.r/255,cast(float32)c.g/255,cast(float32)c.b/255,1];
        for j:0..2 tint[j]+=(1-tint[j])*r.flash;
        dark:=float32.[tint[0]*.45,tint[1]*.45,tint[2]*.45,1];
        fps_box(r.pos+W.Vec3.{0,.42,0},.{.5,.84,.34},dark,p.yaw);
        fps_box(r.pos+W.Vec3.{0,1.13,0},.{.64,.62,.4},tint,p.yaw);
        fps_box(r.pos+W.Vec3.{0,1.6,0},.{.4,.4,.4},tint,p.yaw);
        fwd:=look(p.yaw,0); right:=W.Vec3.{cos(p.yaw),0,-sin(p.yaw)};
        fps_box(r.pos+W.Vec3.{0,1.2,0}+right*.3+look(p.yaw,p.pitch)*.3,.{.09,.12,.62},.[.16,.17,.2,1],p.yaw,p.pitch);
        fps_box(r.pos+W.Vec3.{0,1.64,0}+fwd*.2,.{.3,.09,.04},.[.95,.98,1,1],p.yaw,0,true);
        if voice_speaking(r.id) fps_box(r.pos+W.Vec3.{0,2.2+sin(view.time*6)*.05,0},.{.16,.16,.16},.[.4,1,.85,1],view.time*2,0,true);
    }
    if alive {
        fwd:=look(cy,cp); right:=W.Vec3.{cos(cy),0,-sin(cy)}; up:=W.Vec3.{-right.z*fwd.y,right.z*fwd.x-right.x*fwd.z,right.x*fwd.y};
        me:=local_player(); bob:float32; if me!=null bob=sin(view.time*9)*.006*min(cast(float32)1,sqrt(me.vel.x*me.vel.x+me.vel.z*me.vel.z)/6);
        base:=eye_position+fwd*(.55-view.kick*.05)+right*.17-up*(.15-bob);
        fps_box(base,.{.045,.06,.3},.[.2,.21,.25,1],cy,cp+view.kick*.04);
        fps_box(base-fwd*.09-up*.05,.{.04,.09,.05},.[.32,.24,.17,1],cy,cp+.25);
        fps_box(base+up*.036-fwd*.03,.{.012,.012,.12},.[.2,.7,.62,1],cy,cp);
        if view.muzzle>0 { s:=.03+.025*view.muzzle; fps_box(base+fwd*.18,.{s,s,s},.[1,.85,.45,1],cy+view.time*7,cp,true); }
    }
    for shot:shots { k:=shot.life/.09; fps_box(shot.to,W.Vec3.{.12,.12,.12}*k,.[1,.75,.35,1],view.time*5,0,true); }
}
