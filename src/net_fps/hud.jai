Score_Row :: struct { slot,kills,deaths:s32; local:bool; }
hud_panel :: (id:string,r:F.Rect,c:F.Color,z:s16=10) {
    d:=UI.ui_column_decl(); d.id=CLAY.ID(id); d.backgroundColor=UI.ui_clay_color(c); d.cornerRadius=CLAY.CornerRadiusAll(12/game_scale);
    d.layout.sizing=.{width=CLAY.SizingFixed(r.w/game_scale),height=CLAY.SizingFixed(r.h/game_scale)};
    d.floating=.{attachTo=.ROOT,offset=.[r.x/game_scale,r.y/game_scale],zIndex=z,pointerCaptureMode=.PASSTHROUGH}; CLAY.UI(d);
}
fps_hud :: () {
    view.label_id=0; w:=cast(float32)game_width; h:=cast(float32)game_height; ui:=clamp(min(w/1280,h/800),cast(float32).6,cast(float32)3);
    center:=F.Vector2.{w/2,h/2}; pad:=26*ui; me:=local_player(); reg:=ifx client then *client_reg else *server_reg;
    if view.damage_flash>0 {
        edge:=120*ui; red:=fade(DANGER,.55*view.damage_flash);
        _=G2.rect_gradient(*game_canvas,.{0,0,w,edge},red,red,.{},.{}); _=G2.rect_gradient(*game_canvas,.{0,h-edge,w,edge},.{},.{},red,red);
        _=G2.rect_gradient(*game_canvas,.{0,0,edge,h},red,.{},.{},red); _=G2.rect_gradient(*game_canvas,.{w-edge,0,edge,h},.{},red,red,.{});
    }
    if me!=null && me.respawn<=0 {
        gap:=(6+10*view.spread)*ui; arm:=9*ui;
        for d:F.Vector2.[.{1,0},.{-1,0},.{0,1},.{0,-1}] {
            a:=center+d*gap; b:=center+d*(gap+arm);
            _=G2.line(*game_canvas,a+F.Vector2.{1,1},b+F.Vector2.{1,1},2.5*ui,fade(INK,.6)); _=G2.line(*game_canvas,a,b,2.5*ui,WHITE);
        }
        _=G2.circle(*game_canvas,center,1.8*ui,8,WHITE);
        if view.hitmarker>0 for d:F.Vector2.[.{1,1},.{-1,1},.{1,-1},.{-1,-1}] _=G2.line(*game_canvas,center+d*(9*ui),center+d*(17*ui),3*ui,fade(ifx view.hit_head then DANGER else WHITE,view.hitmarker));
    }
    rows:[..]Score_Row; defer array_free(rows);
    for obj:reg.objects { p:=O.component_data(obj,Player,1); if p!=null array_add(*rows,Score_Row.{p.slot,p.kills,p.deaths,p==me}); }
    status:=tprint("HOSTING  :%",port); if mode==.Server status=tprint("SERVER  :%  (spectating)",port); else if mode==.Client status=tprint("CLIENT  %:%",to_string(address.data),port);
    line:=tprint("%   % players",status,rows.count); if client && mode==.Client && sess.client_authenticated line=tprint("%   ping % ms",line,cast(int)N.stats(*runtime.client).rtt_ms);
    panel_w:=max(text_width(line,17*ui),text_width("NET FPS",30*ui))+26*ui;
    round_rect(.{pad-12*ui,10*ui,panel_w,72*ui},14*ui,fade(BG,.55)); text("NET FPS",.{pad,16*ui},30*ui,WHITE); text(line,.{pad,52*ui},17*ui,DIM);
    for f,i:view.feed {
        alpha:=min(cast(float32)1,f.life); killer:=tprint("P%",f.killer+1); victim:=tprint("P%",f.victim+1); mid:=ifx f.head then "  HEADSHOT  " else "  >  ";
        y:=18*ui+cast(float32)i*30*ui; total:=text_width(killer,18*ui)+text_width(mid,15*ui)+text_width(victim,18*ui); x:=w-pad-total;
        round_rect(.{x-10*ui,y-3*ui,total+20*ui,28*ui},8*ui,fade(INK,.45*alpha)); text(killer,.{x,y},18*ui,fade(slot_color(f.killer),alpha)); x+=text_width(killer,18*ui);
        text(mid,.{x,y+3*ui},15*ui,fade(ifx f.head then DANGER else DIM,alpha)); x+=text_width(mid,15*ui); text(victim,.{x,y},18*ui,fade(slot_color(f.victim),alpha));
    }
    if me!=null {
        hp:=max(me.health,0); round_rect(.{pad-14*ui,h-124*ui,290*ui,86*ui},14*ui,fade(BG,.6)); round_rect(.{w-pad-196*ui,h-124*ui,210*ui,86*ui},14*ui,fade(BG,.6));
        bar:=F.Rect.{pad,h-58*ui,260*ui,12*ui}; _=G2.rect(*game_canvas,bar,fade(WHITE,.15)); bar.w*=cast(float32)hp/100;
        if bar.w>1 _=G2.rect(*game_canvas,bar,ifx hp>35 then NEON else mix(DANGER,WHITE,.3+.3*sin(view.time*10)));
        text(tprint("%",hp),.{pad,h-112*ui},46*ui,WHITE); text("HEALTH",.{pad+text_width(tprint("%",hp),46*ui)+10*ui,h-88*ui},15*ui,DIM);
        text(tprint("%  /  %",me.kills,me.deaths),.{w-pad,h-100*ui},34*ui,WHITE,1); text("KILLS / DEATHS",.{w-pad,h-58*ui},15*ui,DIM,1);
    }
    if lag>0 && client { st:=N.stats(*runtime.client); text(tprint("lag % ms   lead % ticks   corrections %",lag,st.prediction_lead,st.corrections),.{w/2,h-30*ui},15*ui,fade(NEON,.8),.5); }
    else {
        hint:="WASD move   SPACE jump   LMB fire   V talk   F1 voice check   TAB scores   ESC release mouse"; hw:=text_width(hint,15*ui);
        round_rect(.{w/2-hw/2-12*ui,h-34*ui,hw+24*ui,26*ui},13*ui,fade(BG,.5)); text(hint,.{w/2,h-32*ui},15*ui,fade(WHITE,.85),.5);
    }
    voice_hud(w,h,ui);
    if me!=null && me.respawn>0 {
        hud_panel("fps-death",.{0,0,w,h},.{60,0,0,89},20); text("ELIMINATED",.{w/2,h*.36},72*ui,DANGER,.5,21);
        text(tprint("respawning in %",formatFloat(me.respawn,trailing_width=1)),.{w/2,h*.36+90*ui},22*ui,WHITE,.5,21);
    } else if client && me==null {
        hud_panel("fps-connecting",.{0,0,w,h},.{12,14,24,140},20);
        text(ifx sess.client_authenticated then "Server is full - spectating" else tprint("Connecting to %:%",to_string(address.data),port),center+F.Vector2.{0,-20*ui},28*ui,WHITE,.5,21);
        text("ESC  back to menu",center+F.Vector2.{0,30*ui},16*ui,DIM,.5,21);
    }
    if !mouse_look && client && !game_shot && !game_smoke {
        hud_panel("fps-paused",.{0,0,w,h},.{12,14,24,128},20); text("PAUSED",.{w/2,h*.36},64*ui,WHITE,.5,21);
        text("click to resume      ESC  leave to menu",.{w/2,h*.36+84*ui},20*ui,DIM,.5,21); voice_devices(w,h,ui);
    }
    if F.keyboard_down(F.input_keyboard(F.App.input),.TAB) || has_arg("scoreboard") || mode==.Server {
        for i:0..rows.count-1 for j:i+1..rows.count-1 if rows[j].kills>rows[i].kills || (rows[j].kills==rows[i].kills && rows[j].deaths<rows[i].deaths) { tmp:=rows[i]; rows[i]=rows[j]; rows[j]=tmp; }
        panel:=F.Rect.{w/2-220*ui,h*.22,440*ui,56*ui+34*ui*cast(float32)rows.count}; hud_panel("fps-scores",panel,.{8,10,20,209},25);
        text("PLAYER",.{panel.x+24*ui,panel.y+16*ui},14*ui,DIM,0,26); text("K",.{panel.x+panel.w-110*ui,panel.y+16*ui},14*ui,DIM,.5,26); text("D",.{panel.x+panel.w-50*ui,panel.y+16*ui},14*ui,DIM,.5,26);
        for row,i:rows { y:=panel.y+44*ui+cast(float32)i*34*ui;
            if row.local hud_panel(tprint("fps-score-row-%",i),.{panel.x+10*ui,y-2*ui,panel.w-20*ui,28*ui},.{255,255,255,18},25);
            hud_panel(tprint("fps-score-dot-%",i),.{panel.x+24*ui,y+5*ui,10*ui,10*ui},slot_color(row.slot),26);
            text(tprint("P%%",row.slot+1,ifx row.local then "  you" else ""),.{panel.x+46*ui,y},19*ui,slot_color(row.slot),0,26);
            text(tprint("%",row.kills),.{panel.x+panel.w-110*ui,y},19*ui,GOLD,.5,26); text(tprint("%",row.deaths),.{panel.x+panel.w-50*ui,y},19*ui,WHITE,.5,26);
        }
    }
}
