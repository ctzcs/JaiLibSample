// Deterministic replicated-state fixture: exercises presentation events independently
// of random bot encounters. The normal network smoke still runs UDP/ENet separately.
view_test_player:*Player;
view_test_coin:O.Network_Id;
view_test_match:*Match;
view_test_start :: () {
    game_smoke=true; running=true; client=true; sess.client_server_id=44;
    register(*client_reg,true);
    obj:=O.spawn(*client_reg,O.SERVER_OWNED); c:=match_factory(); array_add(*obj.components,c); view_test_match=cast(*Match)c.userdata;
    for i:0..3 {
        obj=O.spawn(*client_reg,cast(TR.Connection_Id)(44+i)); c=player_factory(); array_add(*obj.components,c);
        p:=cast(*Player)c.userdata; p.slot=cast(s32)i; p.pos=.[250+cast(float32)i*210,340];
        if i==0 view_test_player=p;
    }
    for i:0..7 {
        obj=O.spawn(*client_reg,O.SERVER_OWNED); c=coin_factory(); array_add(*obj.components,c); coin:=cast(*Coin)c.userdata;
        coin.pos=.[160+cast(float32)i*125,160]; coin.value=cast(s32) ifx i%3==0 then 5 else 1; if i==0 view_test_coin=obj.id;
    }
}
view_test_update :: (dt:float32) {
    if game_frame==30 { view_test_player.score=5; _=O.despawn(*client_reg,view_test_coin); }
    if game_frame==40 { view_test_player.score=2; view_test_player.hit=1; }
    if game_frame==60 { view_test_player.vel=.[700,0]; view_test_player.dash=1; }
    if game_frame>60 && game_frame<85 view_test_player.pos[0]+=3;
    if game_frame==90 { view_test_match.phase=1; view_test_match.winner=0; view_test_match.time_left=5; }
    if game_frame==120 { view_test_match.phase=0; view_test_match.round=2; view_test_match.time_left=60; view_test_player.score=0; view_test_player.hit=1; }
    view_update(dt);
    if game_frame==1 assert(view.players.count==4 && view.coins.count==8 && view.births==4);
    if game_frame==31 assert(view.pickups==1 && view.popups.count>0 && view.particles.count>=14,"Coin pickup effects missing");
    if game_frame==40 assert(view.shake>0 && view.losses==1,"Local hit shake/effects missing");
    if game_frame==80 { for pv:view.players assert(pv.trail_len==TRAIL); }
    if game_frame==32 view_test_capture("pickup");
    if game_frame==42 view_test_capture("hit");
    if game_frame==80 view_test_capture("dash");
    if game_frame==92 view_test_capture("results");
}
view_test_capture :: (name:string) {
    target:=F.graphics_device_get_backbuffer(F.App.device,F.App.window); image:=F.image_create(target.Width,target.Height); defer F.image_destroy(*image);
    F.texture_get_data(F.target_texture(target),image.Data);
    neon,eyes,gems,dark:int;
    for p:image.Data { if p.g>180 && p.b>150 && p.r<150 neon+=1; if p.r>245 && p.g>245 && p.b>245 eyes+=1; if p.r>120 && p.b>180 && p.g<150 gems+=1; if p.r<40 && p.g<45 && p.b<60 dark+=1; }
    assert(dark>image.Data.count/2,"Arena overlay/background must remain dark, including results");
    if name!="results" assert(neon>1000 && eyes>50 && gems>30,"Arena appearance regressed: neon %, eyes %, gems %",neon,eyes,gems);
    bytes:=F.image_encode_png(image); defer free(bytes.data); assert(FILE.make_directory_if_it_does_not_exist("library/screenshots",true));
    assert(FILE.write_entire_file(tprint("library/screenshots/net_arena-%.png",name),cast(string)bytes));
}
