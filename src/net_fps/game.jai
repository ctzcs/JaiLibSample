RPC :: #import "thirdparty/onet/rpc";
C :: #import "thirdparty/onet/core";
W :: #import "kit/world";
DA :: #import "core/dasset";
MAT :: #import "kit/rendering/material";
R3 :: #import "kit/rendering/3d";
#load "../../shared/geometry3d.jai";
Player :: struct {
    slot,health,kills,deaths:s32; respawn:float32;
    pos,vel:W.Vec3; yaw,pitch:float32; grounded:bool; last_jump:u8;
    bot:bool; ai_bits:u8=1; ai_yaw,ai_pitch,think,strafe,reaction:float32; ai_jump,left:bool; waypoint:W.Vec3;
    fire_cooldown:float32; history:[32]Snapshot;
}
Snapshot :: struct { tick:u64; pos:W.Vec3; }
Box :: struct { lo,hi:W.Vec3; tint:[4]float32; }
Shot :: struct { from,to:W.Vec3; part:u8; victim:s32=-1; life:float32=0.09; own:bool; }
level:[..]Box; shots:[..]Shot;
defaults:[6]u8; mask:[6]u8=.[1,1,1,1,1,1];
input_bits,jump_seq:u8; yaw,pitch,fire_timer,carry:float32;
last_mouse:F.Vector2; mouse_look:bool;
kill_message:string; kill_time:float32; received_shots:int;
spawns:[8]W.Vec3=.[.{-17,0,-17},.{17,0,17},.{-17,0,17},.{17,0,-17},.{0,0,-16},.{0,0,16},.{-16,0,0},.{16,0,0}];
palette:[8][4]float32=.[.[1,.3,.2,1],.[.2,.55,1,1],.[.2,.85,.4,1],.[.85,.4,.95,1],.[1,.8,.2,1],.[.3,.9,.85,1],.[1,.5,.7,1],.[.6,.7,1,1]];
random :: ()->float32 { seed=cast,trunc(u32)(cast(u64)seed*1664525+1013904223); return cast(float32)(seed&0xffffff)/16777216; }
destroy_state :: (data:*void) { free(data); }
player_factory :: ()->*O.Component {
    p:=New(Player); c:=O.component_make(1); c.userdata=p; c.destroy_userdata=destroy_state;
    O.member_i32(c,*p.slot); O.member_i32(c,*p.health); O.member_i32(c,*p.kills); O.member_i32(c,*p.deaths); O.member_f32(c,*p.respawn); return c;
}
register :: (reg:*O.Registry,authority:bool) { O.registry_init(reg,authority); O.register_factory(reg,1,player_factory); }
build_player :: (user:*void,obj:*O.Network_Object)->SIM.System_Config,bool {
    p:=O.component_data(obj,Player,1); if p==null return .{},false;
    return .{schema=0x46500001,state_size=34,input_size=6,defaults=defaults,carry_mask=mask,
        callbacks=.{user=p,capture=capture_player,restore=restore_player,validate_state=validate_player,validate_input=validate_input,sample_input=sample_input,early=step_player}},true;
}
capture_player :: (user:*void,dst:[]u8) {
    p:=cast(*Player)user; at:=0; for v:float32.[p.pos.x,p.pos.y,p.pos.z,p.vel.x,p.vel.y,p.vel.z,p.yaw,p.pitch] SIM.state_put_f32(dst,*at,v);
    SIM.state_put_u8(dst,*at,cast(u8)p.grounded); SIM.state_put_u8(dst,*at,p.last_jump);
}
restore_player :: (user:*void,src:[]u8) {
    p:=cast(*Player)user; at:=0; values:[8]float32; for *v:values v.*,_=SIM.state_get_f32(src,*at);
    p.pos=.{values[0],values[1],values[2]}; p.vel=.{values[3],values[4],values[5]}; p.yaw=values[6]; p.pitch=values[7]; p.grounded=src[32]!=0; p.last_jump=src[33];
}
validate_player :: (user:*void,src:[]u8,tick:SIM.Tick)->bool {
    if src.count!=34 return false; at:=0; for i:0..7 { v,_:=SIM.state_get_f32(src,*at); if !(v>=-10000 && v<=10000) return false; } return src[32]<=1;
}
validate_input :: (user:*void,src:[]u8,tick:SIM.Tick)->bool { return src.count==6 && src[0]<=15; }
sample_input :: (user:*void,dst:[]u8,tick:SIM.Tick) {
    turn:=yaw-floor(yaw/6.2831853)*6.2831853; y:=cast(u16)(turn/6.2831853*65535); pt:=cast(s16)(clamp(pitch/1.5707963,-1,1)*32767); bits:=cast,trunc(u16)pt;
    dst[0]=input_bits; dst[1]=jump_seq; dst[2]=cast,trunc(u8)y; dst[3]=cast(u8)(y>>8); dst[4]=cast,trunc(u8)bits; dst[5]=cast(u8)(bits>>8);
}
step_player :: (user:*void,step:*SIM.World_Step) {
    p:=cast(*Player)user; SIM.world_try_last_state(step); src:=step.input; bits:=src[0]; jump:=src[1]!=p.last_jump; p.last_jump=src[1];
    p.yaw=cast(float32)((cast(u16)src[2])|((cast(u16)src[3])<<8))/65535*6.2831853;
    p.pitch=cast(float32)(cast,trunc(s16)((cast(u16)src[4])|((cast(u16)src[5])<<8)))/32767*1.5707963;
    if p.bot { bits=p.ai_bits; p.yaw=p.ai_yaw; p.pitch=p.ai_pitch; jump=p.ai_jump; p.ai_jump=false; }
    if p.respawn>0 { p.vel=.{}; return; } player_move(p,bits,jump,cast(float32)step.dt);
}
player_move :: (p:*Player,bits:u8,jump:bool,dt:float32) {
    f,r:float32; if bits&1!=0 f+=1; if bits&2!=0 f-=1; if bits&4!=0 r-=1; if bits&8!=0 r+=1;
    wish:=W.Vec3.{-sin(p.yaw)*f+cos(p.yaw)*r,0,-cos(p.yaw)*f-sin(p.yaw)*r}; length:=sqrt(wish.x*wish.x+wish.z*wish.z); if length>0 wish=wish*(7/length);
    delta:=W.Vec3.{wish.x-p.vel.x,0,wish.z-p.vel.z}; len:=sqrt(delta.x*delta.x+delta.z*delta.z); limit:=(ifx p.grounded then cast(float32)60 else 14)*dt; if len>limit delta=delta*(limit/len);
    p.vel.x+=delta.x; p.vel.z+=delta.z; if jump && p.grounded p.vel.y=7.2; p.vel.y=max(p.vel.y-20*dt,cast(float32)-30);
    if move_axis(*p.pos,p.vel.x*dt,0) p.vel.x=0; if move_axis(*p.pos,p.vel.z*dt,2) p.vel.z=0;
    p.grounded=false; if move_axis(*p.pos,p.vel.y*dt,1) { p.grounded=p.vel.y<0; p.vel.y=0; }
}
add_box :: (pos,size:W.Vec3,tint:[4]float32) { array_add(*level,.{pos-size*.5,pos+size*.5,tint}); }
level_build :: () {
    floor_color:=float32.[.52,.56,.62,1]; wall:=float32.[.86,.79,.66,1]; crate:=float32.[.92,.58,.28,1];
    add_box(.{0,-.5,0},.{42,1,42},floor_color); add_box(.{0,2,-20.5},.{42,4,1},wall); add_box(.{0,2,20.5},.{42,4,1},wall);
    add_box(.{-20.5,2,0},.{1,4,40},wall); add_box(.{20.5,2,0},.{1,4,40},wall); add_box(.{0,1.1,0},.{4,2.2,4},.[.74,.76,.84,1]);
    for v:W.Vec3.[.{1,0,0},.{-1,0,0},.{0,0,1},.{0,0,-1}] add_box(.{v.x*2.7,.5,v.z*2.7},.{1.2,1,1.2},crate);
    for x:float32.[-1,1] for z:float32.[-1,1] {
        add_box(.{x*14,2.25,z*14},.{1.4,4.5,1.4},.[.36,.66,.72,1]); add_box(.{x*9,1.1,z*7},.{5,2.2,.8},wall); add_box(.{x*11.1,1.1,z*8.9},.{.8,2.2,3},wall);
        add_box(.{x*5.5,.6,z*13},.{1.2,1.2,1.2},crate); add_box(.{x*6.7,.6,z*13.2},.{1.2,1.2,1.2},crate); add_box(.{x*6.1,1.8,z*13.1},.{1.2,1.2,1.2},crate); add_box(.{x*16,.5,z*3},.{1,1,3},crate);
    }
}
move_axis :: (pos:*W.Vec3,delta:float32,axis:int)->bool {
    if delta==0 return false; p:=cast(*float32)pos; p[axis]+=delta; hit:=false;
    for b:level {
        lo:=pos.*-W.Vec3.{.35,0,.35}; hi:=pos.*+W.Vec3.{.35,1.8,.35};
        if !(lo.x<b.hi.x && hi.x>b.lo.x && lo.y<b.hi.y && hi.y>b.lo.y && lo.z<b.hi.z && hi.z>b.lo.z) continue;
        if delta>0 p[axis]-=(cast(*float32)*hi)[axis]-(cast(*float32)*b.lo)[axis]+.001;
        else p[axis]+=(cast(*float32)*b.hi)[axis]-(cast(*float32)*lo)[axis]+.001;
        hit=true;
    } return hit;
}
look :: (y,p:float32)->W.Vec3 { return .{-sin(y)*cos(p),sin(p),-cos(y)*cos(p)}; }
eye :: (p:W.Vec3)->W.Vec3 { return p+W.Vec3.{0,1.6,0}; }
ray_level :: (origin,dir:W.Vec3,limit:float32)->float32 {
    ray,ok:=W.ray3d_make(origin,dir); if !ok return limit;
    for b:level { t,hit:=W.ray3d_hit_aabb(ray,b.lo,b.hi); if hit && t>=0 limit=min(limit,t); } return limit;
}
place :: (p:*Player) {
    best_gap:float32=-1; for spawn:spawns { gap:float32=10000; for obj:server_reg.objects { other:=O.component_data(obj,Player,1); if other==null || other==p || other.respawn>0 continue; d:=other.pos-spawn; gap=min(gap,sqrt(d.x*d.x+d.y*d.y+d.z*d.z)); } gap+=random()*3; if gap>best_gap { best_gap=gap; p.pos=spawn; } }
    p.vel=.{}; p.yaw=atan2(p.pos.x,p.pos.z); p.ai_yaw=p.yaw; p.pitch=0;
}
add_player :: (owner:TR.Connection_Id,bot:bool=false) {
    used:[8]bool; for obj:server_reg.objects { p:=O.component_data(obj,Player,1); if p!=null used[p.slot]=true; }
    slot:=-1; for taken,i:used if !taken { slot=i; break; } if slot<0 return;
    obj:=O.spawn(*server_reg,owner); c:=player_factory(); array_add(*obj.components,c); p:=cast(*Player)c.userdata; p.slot=cast(s32)slot; p.health=100; p.bot=bot; place(p);
}
register_rpcs :: () {
    if server { RPC.register(*runtime.server.rpc,4,on_voice); RPC.register(*runtime.server.rpc,1,on_fire); RPC.register(*runtime.server.rpc,2,on_shot,.Any_Observer); RPC.register(*runtime.server.rpc,3,on_kill,.Any_Observer); }
    if client { RPC.register(*runtime.client.rpc,4,on_voice); RPC.declare(*runtime.client.rpc,1); RPC.register(*runtime.client.rpc,2,on_shot,.Any_Observer); RPC.register(*runtime.client.rpc,3,on_kill,.Any_Observer); }
}
on_tick :: (s:*S.Session) {
    if !server return; ticks+=1; tick:=server_sim.tick;
    for obj:server_reg.objects {
        p:=O.component_data(obj,Player,1); if p==null continue; p.history[tick%32]=.{tick,p.pos}; p.fire_cooldown=max(cast(float32)0,p.fire_cooldown-.02);
        if p.respawn>0 { p.respawn-=.02; if p.respawn<=0 { p.respawn=0; p.health=100; place(p); } }
        if p.bot && p.respawn<=0 bot_think(obj.id,p);
    }
}
rewound :: (p:*Player,tick:u64)->W.Vec3 { best:=p.pos; best_tick:u64; for h:p.history if h.tick<=tick && h.tick>best_tick { best=h.pos; best_tick=h.tick; } return best; }
on_fire :: (ctx:*RPC.Context,data:[]u8) {
    if !ctx.manager.authority return; p:=O.component_data(ctx.object,Player,1); if p==null || p.respawn>0 || p.fire_cooldown>.04 return;
    r:=RPC.reader(data); y:=C.read_raw_single(*r,0); pt:=C.read_raw_single(*r,0); tick:=C.read_uint64(*r,.Loose);
    if r.err!=.None || !(y>=-10000 && y<=10000 && pt>=-10000 && pt<=10000) return;
    p.fire_cooldown=.16; server_fire(ctx.object.id,p,y,clamp(pt,-1.55,1.55),tick);
}
server_fire :: (id:O.Network_Id,p:*Player,y,pt:float32,view_tick:u64) {
    now:=server_sim.tick; tick:=clamp(view_tick,now-min(now,cast(u64)25),now); origin:=eye(p.pos); dir:=look(y,pt); end:=ray_level(origin,dir,120);
    ray,_:=W.ray3d_make(origin,dir); victim:*Player; part:u8;
    for obj:server_reg.objects {
        o:=O.component_data(obj,Player,1); if o==null || o==p || o.respawn>0 continue; pos:=rewound(o,tick);
        t,hit:=W.ray3d_hit_aabb(ray,pos+W.Vec3.{-.22,1.38,-.22},pos+W.Vec3.{.22,1.82,.22}); hp:u8=2;
        if !hit { t,hit=W.ray3d_hit_aabb(ray,pos+W.Vec3.{-.35,0,-.35},pos+W.Vec3.{.35,1.38,.35}); hp=1; }
        if hit && t>=0 && t<end { end=t; victim=o; part=hp; }
    }
    shot:=Shot.{from=origin,to=origin+dir*end,part=part};
    if victim!=null {
        shot.victim=victim.slot; victim.health-=cast(s32)ifx part==2 then 70 else 25;
        if victim.health<=0 { victim.health=0; victim.respawn=2.5; victim.deaths+=1; p.kills+=1;
            w:C.Writer; C.writer_init(*w); defer C.writer_destroy(*w); C.write_int32(*w,p.slot,.Loose); C.write_int32(*w,victim.slot,.Loose); C.write_boolean(*w,part==2);
            bytes:=C.writer_to_array(*w); defer free(bytes.data); _=RPC.send(*runtime.server.rpc,3,id,.Observers,bytes);
        }
    }
    _=RPC.send_with(*runtime.server.rpc,2,id,.Observers,write_shot,*shot);
}
write_fire :: (w:*C.Writer,user:*void) { C.write_raw_single(w,yaw); C.write_raw_single(w,pitch); C.write_uint64(w,client_sim.applied_tick,.Loose); }
write_shot :: (w:*C.Writer,user:*void) {
    s:=cast(*Shot)user; for v:float32.[s.from.x,s.from.y,s.from.z,s.to.x,s.to.y,s.to.z] C.write_raw_single(w,v); C.write_uint8(w,s.part,.Uncompressed); C.write_int32(w,s.victim,.Loose);
}
on_shot :: (ctx:*RPC.Context,data:[]u8) {
    if ctx.manager.authority return; r:=RPC.reader(data); values:[6]float32; for *v:values v.*=C.read_raw_single(*r,0); part:=C.read_uint8(*r,.Uncompressed); victim:=C.read_int32(*r,.Loose);
    if r.err!=.None || part>2 return; own:=ctx.object.owner==sess.client_server_id; if own { view.muzzle=1; view.kick=1; view.spread=min(view.spread+.35,cast(float32)1); if part>0 { view.hitmarker=1; view.hit_head=part==2; } } array_add(*shots,.{own=own,from=.{values[0],values[1],values[2]},to=.{values[3],values[4],values[5]},part=part,victim=victim}); received_shots+=1;
}
on_kill :: (ctx:*RPC.Context,data:[]u8) {
    if ctx.manager.authority return; r:=RPC.reader(data); killer:=C.read_int32(*r,.Loose); victim:=C.read_int32(*r,.Loose); head:=C.read_boolean(*r);
    if r.err==.None { array_add(*view.feed,Feed.{killer,victim,head,4}); kill_message=tprint("P% eliminated P% %",killer+1,victim+1,ifx head then "HEADSHOT" else ""); kill_time=4; }
}
bot_think :: (id:O.Network_Id,p:*Player) {
    target:*Player; best:float32=40; origin:=eye(p.pos);
    for obj:server_reg.objects { o:=O.component_data(obj,Player,1); if o==null || o==p || o.respawn>0 continue; delta:=o.pos-p.pos; dist:=sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z); if dist>=best || dist<.01 continue; aim:=eye(o.pos)-W.Vec3.{0,.3,0}-origin; len:=sqrt(aim.x*aim.x+aim.y*aim.y+aim.z*aim.z); if ray_level(origin,aim*(1/len),len)>=len-.05 { target=o; best=dist; } }
    p.think-=.02; p.strafe-=.02; if p.strafe<=0 { p.strafe=.4+random()*.8; p.left=random()<.5; }
    aim:=eye(p.waypoint); p.ai_bits=1;
    if target!=null { aim=target.pos+W.Vec3.{0,1.2,0}; p.ai_bits=cast(u8)ifx best>9 then 1 else 0; p.ai_bits|=cast(u8)ifx p.left then 4 else 8; p.reaction-=.02; }
    else { p.reaction=.25+random()*.25; delta:=p.waypoint-p.pos; if p.think<=0 || sqrt(delta.x*delta.x+delta.z*delta.z)<1.5 { p.think=3+random()*3; p.waypoint=spawns[cast(int)(random()*8)]*(.3+random()*.6); } if p.grounded && sqrt(p.vel.x*p.vel.x+p.vel.z*p.vel.z)<1 p.ai_jump=true; }
    d:=aim-origin; want:=atan2(-d.x,-d.z); turn:=want-p.ai_yaw; turn-=floor((turn+3.14159265)/6.2831853)*6.2831853;
    p.ai_yaw+=clamp(turn,-.14,.14); p.ai_pitch+=clamp(atan2(d.y,sqrt(d.x*d.x+d.z*d.z))-p.ai_pitch,-.14,.14);
    if target!=null && abs(turn)<.08 && p.reaction<=0 && p.fire_cooldown<=0 { p.fire_cooldown=.4; server_fire(id,p,p.ai_yaw+(random()-.5)*.07,p.ai_pitch+(random()-.5)*.07,server_sim.tick); }
}
