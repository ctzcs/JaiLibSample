// Reference menu geometry and animation, with kit/Clay owning focus and input.
menu_join:bool;
arena_menu_button :: (id,label:string,r:F.Rect,size:float32,color:F.Color,background:F.Color=.{})->bool {
    state:=UI.ui_interact(*game_ui,id); UI.ui_focus_style(*game_ui,*game_theme,state);
    d:=UI.ui_column_decl(); d.id=CLAY.ID(id);
    d.layout.sizing=.{width=CLAY.SizingFixed(r.w/game_scale),height=CLAY.SizingFixed(r.h/game_scale)};
    d.layout.childAlignment=.{x=.CENTER,y=.CENTER}; d.backgroundColor=UI.ui_clay_color(background);
    d.cornerRadius=CLAY.CornerRadiusAll(12/game_scale);
    d.floating=.{attachTo=.ROOT,offset=.[r.x/game_scale,r.y/game_scale],zIndex=15};
    CLAY.UI(d,#code { game_label(label,cast(u16)max(cast(float32)1,size/game_scale),color); });
    return state.clicked;
}
arena_menu_field :: (id,label:string,buffer:*[..]u8,r:F.Rect,ui:float32,limit:int) {
    text(label,.{r.x,r.y-28*ui},15*ui,DIM);
    theme:=game_theme; theme.body_font_size=cast(u16)max(cast(float32)1,22*ui/game_scale);
    line:=UI.ui_measure_text(*game_font,"M",theme.body_font_size,0,0).height;
    theme.padding=cast(u16)max(cast(float32)1,(r.h/game_scale-line)*.5);
    theme.window_bg=.{9,11,20,255}; theme.panel_border=NEON; theme.accent=NEON; theme.corner_radius=12*ui/game_scale;
    d:=UI.ui_column_decl(); d.id=CLAY.ID(tprint("%-container",id));
    d.floating=.{attachTo=.ROOT,offset=.[r.x/game_scale,r.y/game_scale],zIndex=15};
    CLAY.UI(d,#code { UI.ui_text_input(*game_ui,*theme,id,buffer,"",r.w/game_scale,limit); });
    round_rect_line(r,12*ui,1.5*ui,fade(WHITE,.14));
}
draw_menu_backdrop :: (w,h,ui:float32) {
    horizon:=h*.42; vanish:=F.Vector2.{w/2,horizon};
    for i:-14..14 _=G2.line(*game_canvas,vanish,.{w/2+cast(float32)i*w*.12,h},1.5*ui,fade(NEON,.1));
    scroll:=view.time*.35-floor(view.time*.35);
    for k:0..13 { z:=(cast(float32)k+1-scroll)*.7; y:=horizon+(h-horizon)/(z+.25)*.25;
        if y<=h _=G2.line(*game_canvas,.{0,y},.{w,y},1.5*ui,fade(NEON,clamp((y-horizon)/(h-horizon),cast(float32)0,cast(float32)1)*.22)); }
    _=G2.rect(*game_canvas,.{0,horizon-ui,w,2*ui},fade(NEON,.25));
}
arena_menu :: () {
    view.label_id=0; w:=cast(float32)game_width; h:=cast(float32)game_height; ui:=clamp(min(w/1280,h/800),cast(float32).6,cast(float32)3);
    _=G2.rect(*game_canvas,.{0,0,w,h},BG); _=G2.circle_gradient(*game_canvas,.{w/2,h*.45},max(w,h)*.75,64,BG_GLOW,BG);
    draw_menu_backdrop(w,h,ui);
    card:=F.Rect.{(w-520*ui)/2,(h-640*ui)/2-14*ui,520*ui,640*ui}; cx:=card.x+card.w/2; x:=card.x+40*ui; iw:=440*ui;
    for i:0..4 { g:=cast(float32)(5-i)*8*ui; round_rect(.{card.x-g,card.y-g,card.w+2*g,card.h+2*g},26*ui+g,fade(NEON,.03)); }
    round_rect(card,26*ui,fade(.{16,19,34,255},.94)); round_rect_line(card,26*ui,2*ui,fade(NEON,.45));
    text("NET FPS",.{cx,card.y+30*ui},64*ui,WHITE,.5); text("a tiny arena shooter on onet + Render3D",.{cx,card.y+104*ui},17*ui,DIM,.5);
    track:=F.Rect.{x,card.y+150*ui,iw,52*ui}; round_rect(track,14*ui,.{10,12,22,255});
    active:=F.Rect.{x+(ifx menu_join then iw/2 else 0)+4*ui,track.y+4*ui,iw/2-8*ui,44*ui};
    round_rect(active,11*ui,fade(NEON,.2)); round_rect_line(active,11*ui,1.5*ui,fade(NEON,.7));
    if arena_menu_button("arena-tab-host","HOST A GAME",.{x,track.y,iw/2,track.h},18*ui,ifx menu_join then DIM else WHITE) { menu_join=false; game_ui.focused_id=0; }
    if arena_menu_button("arena-tab-join","JOIN A GAME",.{x+iw/2,track.y,iw/2,track.h},18*ui,ifx menu_join then WHITE else DIM) { menu_join=true; game_ui.focused_id=0; }
    field1:=F.Rect.{x,card.y+266*ui,iw,52*ui}; field2:=F.Rect.{x,card.y+366*ui,iw,52*ui};
    if menu_join {
        arena_menu_field("net-address","HOST ADDRESS",*menu_address,field1,ui,63); arena_menu_field("net-port","PORT",*menu_port,field2,ui,5);
        text("Ask the host for the address shown on their menu",.{cx,field2.y+field2.h+30*ui},15*ui,DIM,.5);
    } else {
        arena_menu_field("net-port","PORT",*menu_port,field1,ui,5);
        text("BOTS",.{x,field2.y-28*ui},15*ui,DIM); text("AI players to fill the arena",.{x,field2.y+15*ui},17*ui,fade(DIM,.8));
        b,ok:=menu_number(menu_bots,0,7); if !ok b=3;
        if arena_menu_button("arena-minus","-",.{x+iw-160*ui,field2.y,52*ui,52*ui},28*ui,ifx b>0 then WHITE else DIM,.{9,11,20,255}) menu_set(*menu_bots,tprint("%",max(0,b-1)));
        if arena_menu_button("arena-plus","+",.{x+iw-52*ui,field2.y,52*ui,52*ui},28*ui,ifx b<7 then WHITE else DIM,.{9,11,20,255}) menu_set(*menu_bots,tprint("%",min(7,b+1)));
        text(menu_text(menu_bots),.{x+iw-80*ui,field2.y+9*ui},26*ui,WHITE,.5);
        info_y:=field2.y+field2.h+22*ui;
        if lan_addresses.count>0 {
            text("Friends on your network join with",.{cx,info_y},15*ui,DIM,.5);
            text(tprint("% : %",lan_addresses[0].text,menu_text(menu_port)),.{cx,info_y+22*ui},22*ui,NEON,.5);
            if lan_addresses.count>1 text(tprint("or  % : %",lan_addresses[1].text,menu_text(menu_port)),.{cx,info_y+52*ui},15*ui,fade(NEON,.6),.5);
        } else text(tprint("Friends join with your IP and port %",menu_text(menu_port)),.{cx,info_y+10*ui},15*ui,DIM,.5);
    }
    btn:=F.Rect.{x,card.y+card.h-112*ui,iw,62*ui}; glow:=.3+.1*sin(view.time*3);
    round_rect(.{btn.x-6*ui,btn.y-2*ui,btn.w+12*ui,btn.h+14*ui},20*ui,fade(NEON,glow*.25));
    clicked:=arena_menu_button(ifx menu_join then "net-join" else "net-host",ifx menu_join then "JOIN GAME" else "START HOSTING",btn,24*ui,.{8,30,28,255},mix(NEON,.{30,160,140,255},.25));
    if clicked || F.keyboard_pressed(F.input_keyboard(F.App.input),.RETURN) { menu_connect(ifx menu_join then .Client else .Host); }
    if message!="Host a match or join an address." && message!="Disconnected." text(message,.{cx,btn.y+btn.h+16*ui},14*ui,DANGER,.5);
    // Optional transport remains available below the reference card.
    if arena_menu_button("net-enet",ifx use_enet then "TRANSPORT: ENET" else "TRANSPORT: UDP",.{cx-100*ui,card.y+card.h+12*ui,200*ui,30*ui},14*ui,NEON) use_enet=!use_enet;
    text("ENTER  start      TAB  next field      CTRL+V  paste      ESC  quit",.{w/2,h-34*ui},15*ui,fade(DIM,.8),.5);
}
