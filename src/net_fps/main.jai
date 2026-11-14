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


Mode :: enum { Host; Server; Client; }
sess: S.Session; runtime: N.Runtime; udp: UDP.Transport; enet: EN.Transport;
server_reg,client_reg: O.Registry;
server_sim,client_sim: SIM.Simulation_World;
mode: Mode; running,server,client: bool;
port: s32=7788; address: [128] u8;
bots: s32=3; lag: s32; use_enet: bool;

message: string="Host a match or join an address.";
seed: u32=1337; ticks,connected: int;

arg_int :: (prefix:string,fallback:int)->int {
    for arg:get_command_line_arguments() {
        if arg.count<=prefix.count continue; same:=true;
        for c,i:prefix if arg.data[i]!=c same=false;
        if !same continue; result:=0;
        for i:prefix.count..arg.count-1 { assert(arg.data[i]>=48 && arg.data[i]<=57); result=result*10+cast(int)arg.data[i]-48; }
        return result;
    } return fallback;
}
main :: () { game_run("net_fps"); }
game_start :: () {
    view_start(); voice_init();
    text:="127.0.0.1"; for c,i:text address[i]=c;
    port=cast(s32)arg_int("port=",7788); bots=cast(s32)arg_int("bots=",3); lag=cast(s32)arg_int("lag=",0); use_enet=has_arg("enet");
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
    if !has_arg("menu-test") && !has_arg("menu") && !has_arg("tracer-test") && (has_arg("host") || has_arg("server") || has_arg("client") || game_shot || game_smoke) net_start();
}
parse_number :: (s:string)->int { n:=0; for c:s { assert(c>=48 && c<=57); n=n*10+cast(int)c-48; } return n; }

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
        for i:0..bots-1 add_player(cast(TR.Connection_Id)(0x7fff0000+i),true);

    }
    register_rpcs();
    ok:bool;
    if mode==.Host ok=S.start_host(*sess,8,cast(u16)port);
    else if mode==.Server ok=S.start_server(*sess,cast(u16)port,8);
    else ok=S.start_client(*sess,to_string(address.data),cast(u16)port);
    running=true; if !ok { message="Could not open the network session."; net_stop(); }
    else { message="Connecting..."; print("net_fps: % on port % (%), bots %, lag % ms\n",mode,port,ifx use_enet then "ENet" else "UDP",bots,lag); }
}
bind_world :: (world:*N.World,simulation:*SIM.Simulation_World,authority:bool) {
    assert(SIM.world_init(simulation,.{authority=authority,fixed_dt=0.02,capacity=128})==.Ok);
    assert(N.bind_simulation(world,simulation)); assert(N.register_world_component(world,1,build_player,null));
}

on_connect :: (s:*S.Session,id:TR.Connection_Id) { if server { add_player(id); connected+=1; print("net_fps: connected %\n",id); } }
on_disconnect :: (s:*S.Session,id:TR.Connection_Id) { if server { obj,ok:=O.find_owned(*server_reg,id); if ok _=O.despawn(*server_reg,obj.id); } }
on_lost :: (s:*S.Session,reason:S.Server_Disconnect_Reason) { if reason!=.Local { message=tprint("Disconnected: %",reason); print("%\n",message); } }

net_stop :: () {
    if !running return; voice_reset(); N.close(*runtime); if client SIM.world_destroy(*client_sim); if server SIM.world_destroy(*server_sim);
    if client O.registry_destroy(*client_reg); if server O.registry_destroy(*server_reg); S.destroy(*sess);
    if use_enet EN.destroy(*enet); else UDP.destroy(*udp);
    sess=.{}; runtime=.{}; server_reg=.{}; client_reg=.{}; server_sim=.{}; client_sim=.{}; udp=.{}; enet=.{};
    fps_view_reset();
    running=false; carry=0; ticks=0; connected=0;
}
game_stop :: () { network_menu_dispose(); net_stop(); view_stop(); voice_stop(); lan_dispose(); }


#load "game.jai";
#load "view.jai";

#load "voice.jai";

#load "../../shared/network_menu.jai";
#load "tracer.jai";

#load "draw2d.jai";
#load "menu.jai";
#load "../net_arena/lan.jai";
#load "presentation.jai";
#load "hud.jai";

#load "voice_ui.jai";
