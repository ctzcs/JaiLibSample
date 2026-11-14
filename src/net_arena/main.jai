#load "../../shared/game_host.jai";
M :: #import "Math";
using M;
using #import "Hash_Table";
O :: #import "thirdparty/onet/objects";
N :: #import "thirdparty/onet/runtime";
S :: #import "thirdparty/onet/session";
SIM :: #import "thirdparty/onet/simulation";
TR :: #import "thirdparty/onet/transport";
UDP :: #import "thirdparty/onet/transport/udp";
EN :: #import "thirdparty/onet/transport/enet";

Player :: struct {
    pos,vel: [2] float32;
    dash,hit,cooldown: float32; last_dash: u8;
    slot,score: s32; bot,want_dash: bool; ai: [2] float32; think: float32;
}
Coin :: struct { pos: [2] float32; value: s32; }
Match :: struct { time_left: float32=60; phase: s32; round: s32=1; winner: s32=-1; }
Mode :: enum { Host; Server; Client; }
sess: S.Session; runtime: N.Runtime; udp: UDP.Transport; enet: EN.Transport;
server_reg,client_reg: O.Registry;
server_sim,client_sim: SIM.Simulation_World;
mode: Mode; running,server,client: bool;
port: s32=7777; address: [128] u8;
bots: s32=3; lag: s32; use_enet: bool;
match: *Match; coin_timer,carry: float32;
input_bits,dash_seq: u8;
message: string="Host a match or join an address.";
seed: u32=1337; ticks,connected: int;
defaults: [2]u8; mask: [2]u8=.[1,1];
operator + :: (a: [2]float32,b: [2]float32)->[2]float32 { return .[a[0]+b[0],a[1]+b[1]]; }
operator - :: (a: [2]float32,b: [2]float32)->[2]float32 { return .[a[0]-b[0],a[1]-b[1]]; }
operator * :: (a: [2]float32,b: float32)->[2]float32 { return .[a[0]*b,a[1]*b]; }
length2 :: (a: [2]float32)->float32 { return sqrt(a[0]*a[0]+a[1]*a[1]); }
unit :: (a: [2]float32)->[2]float32 { len:=length2(a); if len<0.0001 return .[0,0]; return a*(1/len); }
random :: ()->float32 { seed=cast,trunc(u32) (cast(u64) seed*1664525+1013904223); return cast(float32)(seed & 0xffffff)/16777216; }
arg_int :: (prefix:string,fallback:int)->int {
    for arg:get_command_line_arguments() {
        if arg.count<=prefix.count continue; same:=true;
        for c,i:prefix if arg.data[i]!=c same=false;
        if !same continue; result:=0;
        for i:prefix.count..arg.count-1 { assert(arg.data[i]>=48 && arg.data[i]<=57); result=result*10+cast(int)arg.data[i]-48; }
        return result;
    } return fallback;
}
main :: () { game_run("net_arena"); }
game_start :: () {
    if has_arg("view-test") { view_test_start(); return; }
    text:="127.0.0.1"; for c,i:text address[i]=c;
    port=cast(s32)arg_int("port=",7777); bots=cast(s32)arg_int("bots=",3); lag=cast(s32)arg_int("lag=",0); use_enet=has_arg("enet");
    args:=get_command_line_arguments();
    for arg,i:args {
        if arg=="bots" && i+1<args.count bots=cast(s32)parse_number(args[i+1]);
        if arg=="lag" && i+1<args.count lag=cast(s32)parse_number(args[i+1]);
        if arg=="client" && i+1<args.count && args[i+1].count<128 && args[i+1]!="shot" && args[i+1]!="smoke" {
            address=.{}; for c,j:args[i+1] address[j]=c;
            if i+2<args.count && args[i+2].data[0]>=48 && args[i+2].data[0]<=57 port=cast(s32)parse_number(args[i+2]);
        }
        if (arg=="host" || arg=="server") && i+1<args.count && args[i+1].data[0]>=48 && args[i+1].data[0]<=57 port=cast(s32)parse_number(args[i+1]);
    }
    if has_arg("server") mode=.Server; else if has_arg("client") mode=.Client;
    lan_init(); network_menu_init(); menu_join=has_arg("menu-test") || has_arg("join");
    game_ui.focused_id=CLAY.ID("net-port").id;
    if !has_arg("menu-test") && !has_arg("menu") && (has_arg("host") || has_arg("server") || has_arg("client") || game_shot || game_smoke) net_start();
}
parse_number :: (s:string)->int { n:=0; for c:s { assert(c>=48 && c<=57); n=n*10+cast(int)c-48; } return n; }
destroy_state :: (data:*void) { free(data); }
player_factory :: ()->*O.Component {
    p:=New(Player); c:=O.component_make(1); c.userdata=p; c.destroy_userdata=destroy_state;
    O.member_i32(c,*p.slot); O.member_i32(c,*p.score); return c;
}
coin_factory :: ()->*O.Component {
    p:=New(Coin); c:=O.component_make(2); c.userdata=p; c.destroy_userdata=destroy_state;
    O.member_vec2(c,*p.pos); O.member_i32(c,*p.value); return c;
}
match_factory :: ()->*O.Component {
    p:=New(Match); c:=O.component_make(3); c.userdata=p; c.destroy_userdata=destroy_state;
    O.member_f32(c,*p.time_left); O.member_i32(c,*p.phase); O.member_i32(c,*p.round); O.member_i32(c,*p.winner); return c;
}
register :: (reg:*O.Registry,authority:bool) {
    O.registry_init(reg,authority); O.register_factory(reg,1,player_factory); O.register_factory(reg,2,coin_factory); O.register_factory(reg,3,match_factory);
}
net_start :: () {
    assert(port>0 && port<=65535 && bots>=0 && bots<8 && lag>=0);
    S.init(*sess,20); if use_enet { EN.init(*enet); assert(S.set_driver(*sess,EN.driver(*enet))); }
    else { assert(UDP.init(*udp,UDP.default_config())); assert(S.set_driver(*sess,UDP.driver(*udp))); }
    if lag>0 S.set_network_conditions(*sess,.{seed=1,latency_ms=lag,jitter_ms=lag/5});
    server=mode!=.Client; client=mode!=.Server;
    config:N.Config;
    if server { register(*server_reg,true); server_reg.reclaim_despawned=true; config.server_registry=*server_reg; }
    if client { register(*client_reg,false); config.client_registry=*client_reg; }
    assert(N.init(*runtime,*sess,config));
    if server bind_world(*runtime.server,*server_sim,true);
    if client bind_world(*runtime.client,*client_sim,false);
    sess.on_tick=on_tick; sess.on_client_connected=on_connect; sess.on_client_disconnected=on_disconnect; sess.on_server_disconnected=on_lost;
    sess.limits.connect_timeout_ms=5000;
    if server {
        obj:=O.spawn(*server_reg,O.SERVER_OWNED); c:=match_factory(); array_add(*obj.components,c); match=cast(*Match)c.userdata;
        for i:0..bots-1 add_player(cast(TR.Connection_Id)(0x7fff0000+i),true);
        for i:0..13 spawn_coin(random_spot(),cast(s32) ifx random()<0.12 then 5 else 1);
    }
    ok:bool;
    if mode==.Host ok=S.start_host(*sess,8,cast(u16)port);
    else if mode==.Server ok=S.start_server(*sess,cast(u16)port,8);
    else ok=S.start_client(*sess,to_string(address.data),cast(u16)port);
    running=true; if !ok { message="Could not open the network session."; net_stop(); }
    else { message="Connecting..."; print("net_arena: % on port % (%), bots %, lag % ms\n",mode,port,ifx use_enet then "ENet" else "UDP",bots,lag); }
}
bind_world :: (world:*N.World,simulation:*SIM.Simulation_World,authority:bool) {
    assert(SIM.world_init(simulation,.{authority=authority,fixed_dt=0.02,capacity=128})==.Ok);
    assert(N.bind_simulation(world,simulation)); assert(N.register_world_component(world,1,build_player,null));
}
build_player :: (user:*void,obj:*O.Network_Object)->SIM.System_Config,bool {
    p:=O.component_data(obj,Player,1); if p==null return .{},false;
    return .{schema=0x4e410002,state_size=29,input_size=2,defaults=defaults,carry_mask=mask,
        callbacks=.{user=p,capture=capture_player,restore=restore_player,validate_state=validate_player,validate_input=validate_input,sample_input=sample_input,early=step_player}},true;
}
capture_player :: (user:*void,dst:[]u8) {
    p:=cast(*Player)user; at:=0; SIM.state_put_vec2(dst,*at,p.pos); SIM.state_put_vec2(dst,*at,p.vel);
    SIM.state_put_f32(dst,*at,p.dash); SIM.state_put_f32(dst,*at,p.cooldown); SIM.state_put_f32(dst,*at,p.hit); SIM.state_put_u8(dst,*at,p.last_dash);
}
restore_player :: (user:*void,data:[]u8) {
    p:=cast(*Player)user; at:=0; p.pos,_=SIM.state_get_vec2(data,*at); p.vel,_=SIM.state_get_vec2(data,*at);
    p.dash,_=SIM.state_get_f32(data,*at); p.cooldown,_=SIM.state_get_f32(data,*at); p.hit,_=SIM.state_get_f32(data,*at); p.last_dash,_=SIM.state_get_u8(data,*at);
}
validate_player :: (user:*void,data:[]u8,tick:SIM.Tick)->bool {
    if data.count!=29 return false; at:=0; for i:0..6 { v,ok:=SIM.state_get_f32(data,*at); if !ok || !(v>=-1.0e5 && v<=1.0e5) return false; } return true;
}
validate_input :: (user:*void,data:[]u8,tick:SIM.Tick)->bool { return data.count==2 && data[0]<=15; }
sample_input :: (user:*void,dst:[]u8,tick:SIM.Tick) { dst[0]=input_bits; dst[1]=dash_seq; }
step_player :: (user:*void,step:*SIM.World_Step) {
    p:=cast(*Player)user; SIM.world_try_last_state(step);
    dir:[2]float32; bits:=step.input[0]; if bits&1!=0 dir[1]-=1; if bits&2!=0 dir[1]+=1; if bits&4!=0 dir[0]-=1; if bits&8!=0 dir[0]+=1;
    dir=unit(dir); dash:=step.input[1]!=p.last_dash; p.last_dash=step.input[1];
    if p.bot { dir=p.ai; dash=p.want_dash; p.want_dash=false; }
    player_move(p,dir,dash,cast(float32)step.dt);
}
player_move :: (p:*Player,dir:[2]float32,dash:bool,dt:float32) {
    if dash && p.cooldown<=0 { d:=dir; if length2(d)==0 d=unit(p.vel); if length2(d)==0 d=.[1,0]; p.vel=d*980; p.dash=1; p.cooldown=1.1; }
    p.vel=(p.vel+dir*(2600*dt))*exp(-5.5*dt); speed:=length2(p.vel); if p.dash<0.3 && speed>380 p.vel=p.vel*(380/speed);
    p.pos=p.pos+p.vel*dt; bounds:=float32.[1200,680];
    for axis:0..1 { if p.pos[axis]<22 { p.pos[axis]=22; p.vel[axis]=abs(p.vel[axis])*0.6; } else if p.pos[axis]>bounds[axis]-22 { p.pos[axis]=bounds[axis]-22; p.vel[axis]=-abs(p.vel[axis])*0.6; } }
    p.dash=max(cast(float32)0,p.dash-dt*2.4); p.hit=max(cast(float32)0,p.hit-dt/1.2); p.cooldown=max(cast(float32)0,p.cooldown-dt);
}
random_spot :: ()->[2]float32 {
    best:[2]float32; best_gap:float32=-1;
    for i:0..5 { point:=float32.[60+random()*1080,60+random()*560]; gap:float32=1.0e9;
        for obj:server_reg.objects { p:=O.component_data(obj,Player,1); if p!=null gap=min(gap,length2(p.pos-point)); }
        if gap>best_gap { best=point; best_gap=gap; }
    } return best;
}
add_player :: (owner:TR.Connection_Id,bot:bool=false) {
    used:[8]bool; for obj:server_reg.objects { p:=O.component_data(obj,Player,1); if p!=null used[p.slot]=true; }
    slot:=-1; for taken,i:used if !taken { slot=i; break; } if slot<0 return;
    obj:=O.spawn(*server_reg,owner); c:=player_factory(); array_add(*obj.components,c); p:=cast(*Player)c.userdata;
    p.slot=cast(s32)slot; p.bot=bot; p.pos=random_spot(); p.hit=1;
}
spawn_coin :: (pos:[2]float32,value:s32) {
    obj:=O.spawn(*server_reg,O.SERVER_OWNED); if obj==null return; c:=coin_factory(); array_add(*obj.components,c);
    coin:=cast(*Coin)c.userdata; coin.pos=.[clamp(pos[0],30,1170),clamp(pos[1],30,650)]; coin.value=value;
}
on_connect :: (s:*S.Session,id:TR.Connection_Id) { if server { add_player(id); connected+=1; print("net_arena: connected %\n",id); } }
on_disconnect :: (s:*S.Session,id:TR.Connection_Id) { if server { obj,ok:=O.find_owned(*server_reg,id); if ok _=O.despawn(*server_reg,obj.id); } }
on_lost :: (s:*S.Session,reason:S.Server_Disconnect_Reason) { if reason!=.Local { message=tprint("Disconnected: %",reason); print("%\n",message); } }
on_tick :: (s:*S.Session) {
    if !server return; ticks+=1;
    players:[..]*Player; coins:[..]O.Network_Id; defer { array_free(players); array_free(coins); }
    for obj,id:server_reg.objects { p:=O.component_data(obj,Player,1); if p!=null array_add(*players,p); else if O.component_data(obj,Coin,2)!=null array_add(*coins,id); }
    match.time_left=max(cast(float32)0,match.time_left-0.02);
    playing:=match.phase==0;
    if match.time_left<=0 {
        if match.phase==0 { match.phase=1; match.time_left=5; match.winner=-1; best:s32=-1; for p:players if p.score>best { best=p.score; match.winner=p.slot; } }
        else { match.phase=0; match.time_left=60; match.round+=1; for p:players { p.score=0; p.vel=.{}; p.hit=1; p.pos=random_spot(); } }
    }
    for p:players if p.bot {
        p.think-=0.02; if p.think>0 continue; p.think=0.12+random()*0.18; target:=float32.[600,340]; best:float32=1.0e9;
        for id:coins { obj,_:=O.get(*server_reg,id); c:=O.component_data(obj,Coin,2); if c==null continue; cost:=length2(c.pos-p.pos)/sqrt(cast(float32)c.value)+random()*60; if cost<best { best=cost; target=c.pos; } }
        for other:players if other!=p && other.hit<=0 && other.score>0 && length2(other.pos-p.pos)<170 && p.cooldown<=0 && random()<0.25 { target=other.pos; p.want_dash=true; break; }
        p.ai=unit(unit(target-p.pos)+float32.[random()*0.5-0.25,random()*0.5-0.25]);
    }
    for a,i:players for b,j:players {
        if j<=i continue; delta:=b.pos-a.pos; dist:=length2(delta); if dist>=44 || dist<0.0001 continue;
        normal:=delta*(1/dist); push:=normal*((44-dist)*0.5); a.pos=a.pos-push; b.pos=b.pos+push;
        v:=b.vel-a.vel; vn:=v[0]*normal[0]+v[1]*normal[1]; if vn<0 { impulse:=normal*(-vn*0.9); a.vel=a.vel-impulse; b.vel=b.vel+impulse; }
        if playing { if a.dash>0.5 && b.dash<=0.5 knock(b,normal); if b.dash>0.5 && a.dash<=0.5 knock(a,normal*(-1)); }
    }
    if playing {
        for id:coins { obj,_:=O.get(*server_reg,id); c:=O.component_data(obj,Coin,2); if c==null continue;
            for p:players if length2(p.pos-c.pos)<33 { p.score+=c.value; _=O.despawn(*server_reg,id); break; }
        }
        coin_timer-=0.02; if coins.count<14 && coin_timer<=0 { coin_timer=0.35; spawn_coin(random_spot(),cast(s32) ifx random()<0.12 then 5 else 1); }
    }
}
knock :: (victim:*Player,away:[2]float32) {
    if victim.hit>0 return; victim.hit=1; victim.vel=victim.vel+away*520; lost:=min(victim.score,3); victim.score-=lost;
    for k:0..lost-1 { angle:=atan2(away[1],away[0])+(cast(float32)k-cast(float32)(lost-1)*0.5)*0.9; spawn_coin(victim.pos+float32.[cos(angle),sin(angle)]*70,1); }
}
game_update :: (dt:float32) {
    if has_arg("view-test") { view_test_update(dt); return; }
    if has_arg("menu-test") && game_frame==8 menu_join=false;
    keys:=F.input_keyboard(F.App.input);
    if !game_text_captured && F.keyboard_pressed(keys,.ESCAPE) { if running { net_stop(); message="Disconnected."; } else F.app_exit(); }
    input_bits=0;
    if running && !game_text_captured && !game_capture.keyboard && F.window_focused(F.App.window) {
        if F.keyboard_down(keys,.W) || F.keyboard_down(keys,.UP) input_bits|=1;
        if F.keyboard_down(keys,.S) || F.keyboard_down(keys,.DOWN) input_bits|=2;
        if F.keyboard_down(keys,.A) || F.keyboard_down(keys,.LEFT) input_bits|=4;
        if F.keyboard_down(keys,.D) || F.keyboard_down(keys,.RIGHT) input_bits|=8;
        if F.keyboard_pressed(keys,.SPACE) || F.keyboard_pressed(keys,.LEFT_SHIFT) dash_seq=cast,trunc(u8)(cast(u16)dash_seq+1);
    }
    if running {
        if game_smoke && !has_arg("menu-test") { input_bits=8; if game_frame==20 dash_seq+=1; }
        carry+=min(dt,cast(float32)0.1)*1000; ms:=cast(int)carry; carry-=cast(float32)ms; if ms>0 N.update(*runtime,ms);
        if has_arg("frames=600") && game_frame>=600 F.app_exit();
    }
    view_update(dt);
}
game_draw :: () {
    if !running { arena_menu(); return; }
    view_render();
}

game_ready :: ()->bool {
    if has_arg("view-test") return game_frame>150;
    if has_arg("menu") return true;
    if !running || game_frame<=180 return false;
    if !client return ticks>20;
    obj,ok:=O.find_owned(*client_reg,sess.client_server_id);
    return ok && client_reg.active_count>3 && client_sim.applied_tick>0 && !client_sim.needs_full;
}
game_check :: () {
    if has_arg("view-test") { assert(view_test_match.round==2 && view_test_match.phase==0 && view.losses==2); print("Arena presentation: spawn, pickup, hit, dash, trails, results and restart PASS\n"); return; }
    if has_arg("menu") return;
    if has_arg("menu-test") assert(menu_input_checks==4);
    assert(running); if client { obj,ok:=O.find_owned(*client_reg,sess.client_server_id); assert(ok,"Client never received its owned player"); p:=O.component_data(obj,Player,1); assert(p!=null,"Missing player component"); assert(p.pos[0]>=22 && p.pos[0]<=1178,"Player outside arena: %",p.pos); assert(!client_sim.needs_full,"Client needs a full snapshot"); }
    if server assert(ticks>0 && server_reg.active_count>=bots+1);
    print("network: ticks %, server objects %, client objects %, connected %\n",ticks,server_reg.active_count,client_reg.active_count,connected);
}
net_stop :: () {
    if !running return; N.close(*runtime); if client SIM.world_destroy(*client_sim); if server SIM.world_destroy(*server_sim);
    if client O.registry_destroy(*client_reg); if server O.registry_destroy(*server_reg); S.destroy(*sess);
    if use_enet EN.destroy(*enet); else UDP.destroy(*udp);
    sess=.{}; runtime=.{}; server_reg=.{}; client_reg=.{}; server_sim=.{}; client_sim=.{}; udp=.{}; enet=.{};
    view_reset();
    running=false; match=null; carry=0; ticks=0; connected=0;
}
game_stop :: () {
    if has_arg("view-test") { O.registry_destroy(*client_reg); view_dispose(); return; } network_menu_dispose(); net_stop(); view_dispose(); lan_dispose(); }



#load "../../shared/network_menu.jai";

#load "view.jai";

#load "menu.jai";

#load "view_checks.jai";

#load "lan.jai";
