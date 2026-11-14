// Translation of olib_sample/src/net_arena/{view,draw2d}.odin.
// Replicated state is read-only here. Smoothing and effects never affect simulation.
TRAIL :: 14;
Visual :: struct {
    id: O.Network_Id; pos: [2]float32; facing: float32; score:s32;
    trail:[TRAIL][2]float32; trail_head,trail_len:int; trail_t:float32; seen:bool;
}
Coin_Visual :: struct { id:O.Network_Id; pos:[2]float32; value:s32; age:float32; seen:bool; }
Particle :: struct { pos,vel:[2]float32; life,max_life,size:float32; color:F.Color; }
Popup :: struct { pos:[2]float32; value:s32; life:float32; }
View :: struct {
    players:[..]Visual; coins:[..]Coin_Visual; particles:[..]Particle; popups:[..]Popup;
    time,shake:float32; origin:F.Vector2; scale:float32=1; label_id:int;
    random_seed:u32=751; births,pickups,losses:int;
}
view:View;
BG :: F.Color.{12,14,24,255}; BG_GLOW :: F.Color.{26,30,54,255};
FLOOR :: F.Color.{20,24,40,255}; GRID :: F.Color.{32,38,62,255};
NEON :: F.Color.{94,234,212,255}; WHITE :: F.Color.{255,255,255,255}; INK :: F.Color.{0,0,0,255};
DIM :: F.Color.{140,150,180,255}; GOLD :: F.Color.{255,209,102,255}; GOLD_DARK :: F.Color.{214,140,38,255};
GEM :: F.Color.{232,121,249,255}; GEM_DARK :: F.Color.{147,51,234,255}; DANGER :: F.Color.{255,99,99,255};
SLOT_COLORS :: F.Color.[.{255,107,107,255},.{77,171,247,255},.{105,219,124,255},.{252,196,25,255},
    .{151,117,250,255},.{240,101,149,255},.{56,217,169,255},.{255,146,43,255}];
slot_color :: (slot:s32)->F.Color { return SLOT_COLORS[slot%8]; }
fade :: (c:F.Color,alpha:float32)->F.Color {
    t:=clamp(alpha,cast(float32)0,cast(float32)1);
    return .{cast(u8)(cast(float32)c.r*t),cast(u8)(cast(float32)c.g*t),cast(u8)(cast(float32)c.b*t),cast(u8)(cast(float32)c.a*t)};
}
mix :: (a,b:F.Color,t:float32)->F.Color { return F.color_lerp(a,b,t); }
v2 :: (p:[2]float32)->F.Vector2 { return .{p[0],p[1]}; }
view_random :: ()->float32 {
    view.random_seed=cast,trunc(u32)(cast(u64)view.random_seed*1664525+1013904223);
    return cast(float32)(view.random_seed&0xffffff)/16777216;
}
view_registry :: ()->*O.Registry { return ifx client then *client_reg else *server_reg; }
local_player :: ()->O.Network_Id {
    if !client return 0; obj,ok:=O.find_owned(*client_reg,sess.client_server_id); if ok return obj.id; return 0;
}
find_match :: (reg:*O.Registry)->*Match { for obj:reg.objects { m:=O.component_data(obj,Match,3); if m!=null return m; } return null; }
view_reset :: () {
    view.players.count=0; view.coins.count=0; view.particles.count=0; view.popups.count=0; view.shake=0;
}
view_dispose :: () { array_free(view.players); array_free(view.coins); array_free(view.particles); array_free(view.popups); }
burst :: (pos:[2]float32,color:F.Color,count:int,speed:float32) {
    for 0..count-1 {
        angle:=view_random()*TAU; s:=speed*(.35+.65*view_random()); life:=.35+.45*view_random();
        array_add(*view.particles,Particle.{pos=pos,vel=float32.[cos(angle),sin(angle)]*s,life=life,max_life=life,size=2+2.5*view_random(),color=color});
    }
}
view_update :: (dt:float32) {
    view.time+=dt; view.shake=max(cast(float32)0,view.shake-dt*3); if !running return;
    reg:=view_registry(); local_id:=local_player(); follow:=1-exp(-18*dt); follow_local:=1-exp(-45*dt);
    for *pv:view.players pv.seen=false; for *cv:view.coins cv.seen=false;
    for obj,id:reg.objects {
        p:=O.component_data(obj,Player,1); c:=O.component_data(obj,Coin,2);
        if p!=null {
            pv:*Visual; for *it:view.players if it.id==id { pv=it; break; }
            if pv==null {
                array_add(*view.players,Visual.{id=id,pos=p.pos,score=p.score}); pv=*view.players[view.players.count-1];
                burst(p.pos,slot_color(p.slot),24,260); view.births+=1;
            }
            pv.seen=true; pv.pos=pv.pos+(p.pos-pv.pos)*(ifx id==local_id then follow_local else follow);
            if length2(p.vel)>25 pv.facing=atan2(p.vel[1],p.vel[0]);
            if p.score!=pv.score {
                delta:=p.score-pv.score; array_add(*view.popups,Popup.{pv.pos-float32.[0,32],delta,1});
                if delta<0 { burst(pv.pos,DANGER,18,320); view.losses+=1; if id==local_id view.shake=1; }
                pv.score=p.score;
            }
            pv.trail_t-=dt; if pv.trail_t<=0 { pv.trail_t=1.0/60; pv.trail[pv.trail_head]=pv.pos; pv.trail_head=(pv.trail_head+1)%TRAIL; pv.trail_len=min(pv.trail_len+1,TRAIL); }
        } else if c!=null {
            cv:*Coin_Visual; for *it:view.coins if it.id==id { cv=it; break; }
            if cv==null { array_add(*view.coins,Coin_Visual.{id=id,pos=c.pos,value=c.value}); cv=*view.coins[view.coins.count-1]; }
            cv.seen=true; cv.pos=c.pos; cv.value=c.value; cv.age+=dt;
        }
    }
    i:=view.coins.count-1; while i>=0 {
        cv:=view.coins[i]; if !cv.seen { burst(cv.pos,ifx cv.value>1 then GEM else GOLD,ifx cv.value>1 then 26 else 14,220); array_unordered_remove_by_index(*view.coins,i); view.pickups+=1; } i-=1;
    }
    i=view.players.count-1; while i>=0 { pv:=view.players[i]; if !pv.seen { burst(pv.pos,WHITE,30,300); array_unordered_remove_by_index(*view.players,i); } i-=1; }
    i=view.particles.count-1; while i>=0 {
        p:=*view.particles[i]; p.life-=dt; if p.life<=0 array_unordered_remove_by_index(*view.particles,i);
        else { p.pos=p.pos+p.vel*dt; p.vel=p.vel*exp(-4*dt); } i-=1;
    }
    i=view.popups.count-1; while i>=0 { p:=*view.popups[i]; p.life-=dt*.9; p.pos[1]-=46*dt; if p.life<=0 array_ordered_remove_by_index(*view.popups,i); i-=1; }
}
rounded_outline :: (rect:F.Rect,radius:float32)->[28]F.Vector2 {
    r:=min(radius,min(rect.w*.5,rect.h*.5)); x0:=rect.x; y0:=rect.y; x1:=x0+rect.w; y1:=y0+rect.h;
    centers:=F.Vector2.[.{x1-r,y0+r},.{x1-r,y1-r},.{x0+r,y1-r},.{x0+r,y0+r}];
    starts:=float32.[-PI/2,0,PI/2,PI]; points:[28]F.Vector2;
    for c:0..3 for k:0..6 { a:=starts[c]+cast(float32)k/6*(PI/2); points[c*7+k]=centers[c]+F.Vector2.{cos(a)*r,sin(a)*r}; }
    return points;
}
round_rect :: (r:F.Rect,radius:float32,color:F.Color) {
    if r.w<=0 || r.h<=0 return; points:=rounded_outline(r,radius); center:=F.Vector2.{r.x+r.w*.5,r.y+r.h*.5};
    for p,i:points _=G2.triangle(*game_canvas,center,p,points[(i+1)%28],color);
}
round_rect_line :: (r:F.Rect,radius,thickness:float32,color:F.Color) {
    t:=thickness*.5; outer:=rounded_outline(.{r.x-t,r.y-t,r.w+2*t,r.h+2*t},radius+t);
    inner:=rounded_outline(.{r.x+t,r.y+t,r.w-2*t,r.h-2*t},max(radius-t,cast(float32)0));
    for p,i:outer { j:=(i+1)%28; _=G2.quad(*game_canvas,inner[i],p,outer[j],inner[j],color); }
}
to_screen :: (p:[2]float32)->F.Vector2 { return view.origin+v2(p)*view.scale; }
push_local :: (pos:[2]float32,scale:F.Vector2,rotation:float32) {
    G2.push_matrix_trs(*game_canvas,to_screen(pos),scale*view.scale,rotation,false);
}
text_width :: (s:string,size:float32)->float32 { return UI.ui_measure_text(*game_font,s,cast(u16)max(cast(float32)1,size/game_scale),0,0).width*game_scale; }
// Keep the reference's pixel positions, but use the requested kit/Clay UI and bundled MSDF font.
text :: (s:string,pos:F.Vector2,size:float32,color:F.Color,align:float32=0,z:s16=10) {
    view.label_id+=1; d:=UI.ui_column_decl(); d.id=CLAY.ID(tprint("arena-text-%",view.label_id));
    d.floating=.{attachTo=.ROOT,offset=.[(pos.x-text_width(s,size)*align)/game_scale,pos.y/game_scale],zIndex=z,pointerCaptureMode=.PASSTHROUGH};
    // Render2D colors are premultiplied; Clay accepts straight colors and premultiplies once.
    straight:=color;
    if color.a>0 && color.a<255 {
        straight.r=cast(u8)min(255,cast(int)color.r*255/cast(int)color.a);
        straight.g=cast(u8)min(255,cast(int)color.g*255/cast(int)color.a);
        straight.b=cast(u8)min(255,cast(int)color.b*255/cast(int)color.a);
    }
    CLAY.UI(d,#code { game_label(s,cast(u16)max(cast(float32)1,size/game_scale),straight); });
}
view_overlay :: (arena:F.Rect,alpha:u8) {
    overlay:=UI.ui_column_decl(); overlay.id=CLAY.ID("arena-overlay");
    overlay.layout.sizing=.{width=CLAY.SizingFixed(arena.w/game_scale),height=CLAY.SizingFixed(arena.h/game_scale)};
    overlay.backgroundColor=UI.ui_clay_color(.{6,8,16,alpha}); overlay.cornerRadius=CLAY.CornerRadiusAll(22*view.scale/game_scale);
    overlay.floating=.{attachTo=.ROOT,offset=.[arena.x/game_scale,arena.y/game_scale],zIndex=20,pointerCaptureMode=.PASSTHROUGH}; CLAY.UI(overlay);
}
view_ui_dot :: (pos:F.Vector2,radius:float32,color:F.Color) {
    view.label_id+=1; d:=UI.ui_column_decl(); d.id=CLAY.ID(tprint("arena-dot-%",view.label_id));
    d.layout.sizing=.{width=CLAY.SizingFixed(radius*2/game_scale),height=CLAY.SizingFixed(radius*2/game_scale)};
    d.backgroundColor=UI.ui_clay_color(color); d.cornerRadius=CLAY.CornerRadiusAll(radius/game_scale);
    d.floating=.{attachTo=.ROOT,offset=.[(pos.x-radius)/game_scale,(pos.y-radius)/game_scale],zIndex=21,pointerCaptureMode=.PASSTHROUGH}; CLAY.UI(d);
}
draw_arena :: (m:*Match) {
    edge:=NEON; if m!=null && m.phase==0 && m.time_left<10 edge=mix(NEON,DANGER,.5+.5*sin(view.time*8));
    for i:0..4 { g:=cast(float32)(5-i)*7; round_rect(.{-g,-g,1200+2*g,680+2*g},22+g,fade(edge,.035)); }
    round_rect(.{0,0,1200,680},22,FLOOR);
    for i:1..29 { x:=cast(float32)i*40; _=G2.line(*game_canvas,.{x,6},.{x,674},1,GRID); }
    for i:1..16 { y:=cast(float32)i*40; _=G2.line(*game_canvas,.{6,y},.{1194,y},1,GRID); }
    _=G2.circle_line(*game_canvas,.{600,340},110,3,72,fade(edge,.18));
    _=G2.circle(*game_canvas,.{600,340},10,24,fade(edge,.25));
    _=G2.line(*game_canvas,.{600,0},.{600,680},3,fade(edge,.12));
    round_rect_line(.{0,0,1200,680},22,4,edge);
}
draw_coins :: () {
    for cv:view.coins {
        gem:=cv.value>1; t:=min(cv.age*3.5,cast(float32)1); u:=t-1; pop:=1+2.2*u*u*u+1.2*u*u;
        radius:=(ifx gem then cast(float32)14.85 else cast(float32)11)*pop;
        phase:=cv.pos[0]*.031+cv.pos[1]*.017; p:=cv.pos+float32.[0,sin(view.time*3+phase)*3];
        light:=ifx gem then GEM else GOLD; dark:=ifx gem then GEM_DARK else GOLD_DARK;
        _=G2.circle(*game_canvas,v2(cv.pos+float32.[0,radius+6]),radius*.7,16,fade(INK,.3));
        _=G2.circle_gradient(*game_canvas,v2(p),radius*(ifx gem then 3.2 else 2.4),24,fade(light,ifx gem then .35 else .25),.{});
        spin:=.3+.7*abs(cos(view.time*2.4+phase)); push_local(p,.{spin,1},0);
        if gem {
            s:=radius*1.25; _=G2.triangle(*game_canvas,.{0,-s},.{s,0},.{-s,0},light);
            _=G2.triangle(*game_canvas,.{-s,0},.{s,0},.{0,s},dark);
            _=G2.triangle(*game_canvas,.{0,-s},.{s*.35,-s*.2},.{-s*.35,-s*.2},fade(WHITE,.7));
        } else {
            _=G2.circle(*game_canvas,.{},radius,24,dark); _=G2.circle(*game_canvas,.{},radius*.78,24,light);
            _=G2.circle(*game_canvas,.{-radius*.25,-radius*.3},radius*.25,12,fade(WHITE,.75));
        }
        G2.pop_matrix(*game_canvas);
    }
}
draw_blob_body :: (col:F.Color) {
    _=G2.circle_gradient(*game_canvas,.{},22,40,mix(col,WHITE,.35),col);
    _=G2.circle_line(*game_canvas,.{},22,3,40,mix(col,INK,.35));
    for side:float32.[-1,1] {
        eye:=F.Vector2.{22*.38,side*22*.34}; _=G2.circle(*game_canvas,eye,6.5,16,WHITE);
        _=G2.circle(*game_canvas,eye+F.Vector2.{2.2,0},3.2,12,.{20,22,36,255});
    }
}
draw_players :: (reg:*O.Registry,local_id:O.Network_Id) {
    for pv:view.players {
        obj,ok:=O.get(reg,pv.id); if !ok continue; p:=O.component_data(obj,Player,1); if p==null continue;
        col:=slot_color(p.slot); pos:=v2(pv.pos);
        for k:0..pv.trail_len-1 {
            idx:=(pv.trail_head-1-k+TRAIL*2)%TRAIL; t:=1-cast(float32)k/TRAIL;
            _=G2.circle(*game_canvas,v2(pv.trail[idx]),22*(.35+.55*t),20,fade(col,t*(.06+.3*p.dash)));
        }
        _=G2.circle(*game_canvas,pos+F.Vector2.{0,22*.55},22*.95,24,fade(INK,.35));
        if p.dash>0 _=G2.circle_gradient(*game_canvas,pos,66,32,fade(col,.55*p.dash),.{});
        if pv.id==local_id _=G2.circle_line(*game_canvas,pos,31+sin(view.time*5)*2,2.5,48,fade(WHITE,.55));
        stretch:=clamp(length2(p.vel)/1800,cast(float32)0,cast(float32).25);
        push_local(pv.pos,.{1+stretch,1-stretch*.8},pv.facing); draw_blob_body(col);
        if p.hit>0 && sin(view.time*38)>0 _=G2.circle(*game_canvas,.{},23,40,fade(WHITE,.65*p.hit));
        G2.pop_matrix(*game_canvas);
    }
}
draw_labels :: (reg:*O.Registry,local_id:O.Network_Id) {
    for pv:view.players {
        obj,ok:=O.get(reg,pv.id); if !ok continue; p:=O.component_data(obj,Player,1); if p==null continue;
        size:=16*view.scale; name:=tprint("P%%",p.slot+1,ifx pv.id==local_id then "  YOU" else ""); nw:=text_width(name,size);
        at:=to_screen(pv.pos+float32.[0,ifx pv.pos[1]>62 then -44 else 48]);
        tag:=F.Rect.{at.x-nw/2-8*view.scale,at.y-11*view.scale,nw+16*view.scale,22*view.scale};
        round_rect(tag,tag.h/2,fade(INK,.55)); text(name,.{at.x,tag.y+view.scale},size,ifx pv.id==local_id then WHITE else mix(slot_color(p.slot),WHITE,.4),.5);
    }
}
Row :: struct { slot,score:s32; local:bool; }
draw_hud :: (reg:*O.Registry,m:*Match,local_id:O.Network_Id,w,h,ui:float32) {
    rows:[..]Row; defer array_free(rows);
    for obj,id:reg.objects { p:=O.component_data(obj,Player,1); if p!=null array_add(*rows,Row.{p.slot,p.score,id==local_id}); }
    for i:0..rows.count-1 for j:i+1..rows.count-1 if rows[j].score>rows[i].score || (rows[j].score==rows[i].score && rows[j].slot<rows[i].slot) { tmp:=rows[i]; rows[i]=rows[j]; rows[j]=tmp; }
    pad:=28*ui; text("NET ARENA",.{pad,18*ui},34*ui,WHITE);
    status:=tprint("HOSTING  :%",port); if mode==.Server status=tprint("SERVER  :%  (spectating)",port); else if mode==.Client status=tprint("CLIENT  %:%",to_string(address.data),port);
    _=G2.circle(*game_canvas,.{pad+5*ui,66*ui},5*ui,12,NEON);
    line:=tprint("%   % online",status,rows.count); stats:N.Net_Stats; if client stats=N.stats(*runtime.client);
    if mode==.Client && sess.client_authenticated { line=tprint("%   ping % ms",line,cast(int)stats.rtt_ms); if lag>0 line=tprint("%   lead % ticks",line,stats.prediction_lead); }
    text(line,.{pad+16*ui,56*ui},18*ui,DIM);
    if lag>0 text(tprint("lag % ms   corrections %",lag,stats.corrections),.{pad,h-34*ui},15*ui,fade(NEON,.7));
    if m!=null {
        secs:=cast(int)ceil(m.time_left); clock:=tprint("%:%%",secs/60,ifx secs%60<10 then "0" else "",secs%60);
        color:=WHITE; if m.phase==0 && m.time_left<10 color=mix(WHITE,DANGER,.5+.5*sin(view.time*8));
        text(clock,.{w/2,8*ui},54*ui,color,.5); text(tprint("ROUND %",m.round),.{w/2,64*ui},16*ui,DIM,.5);
    }
    panel_w:=210*ui; row_h:=30*ui;
    if rows.count>0 {
        panel:=F.Rect.{view.origin.x+1200*view.scale-panel_w-14*ui,view.origin.y+14*ui,panel_w,row_h*cast(float32)rows.count+14*ui};
        round_rect(panel,12*ui,fade(.{8,10,20,255},.72));
        for row,i:rows {
            y:=panel.y+7*ui+cast(float32)i*row_h; _=G2.circle(*game_canvas,.{panel.x+20*ui,y+row_h*.47},7*ui,16,slot_color(row.slot));
            text(tprint("P%%",row.slot+1,ifx row.local then "  you" else ""),.{panel.x+38*ui,y+4*ui},18*ui,WHITE);
            text(tprint("%",row.score),.{panel.x+panel_w-16*ui,y+4*ui},18*ui,GOLD,1);
        }
    }
    text("WASD / ARROWS  move      SPACE  dash      dash into rivals to knock coins loose      ESC  menu",.{w/2,h-34*ui},16*ui,fade(DIM,.9),.5);
    arena:=F.Rect.{view.origin.x,view.origin.y,1200*view.scale,680*view.scale}; center:=F.Vector2.{arena.x+arena.w/2,arena.y+arena.h/2};
    if m!=null && m.phase==1 {
        view_overlay(arena,179);
        title:="DRAW"; color:=WHITE; if m.winner>=0 { title=tprint("P% WINS",m.winner+1); color=slot_color(m.winner); }
        text(title,center+F.Vector2.{0,-110*ui},84*ui*(1+.04*sin(view.time*6)),color,.5,21);
        for row,i:rows { if i>=5 break; y:=center.y+cast(float32)i*34*ui-10*ui;
            view_ui_dot(.{center.x-90*ui,y+13*ui},8*ui,slot_color(row.slot));
            text(tprint("P%",row.slot+1),.{center.x-70*ui,y},22*ui,WHITE,0,21);
            text(tprint("%",row.score),.{center.x+100*ui,y},22*ui,GOLD,1,21);
        }
        text(tprint("next round in %",cast(int)ceil(m.time_left)),.{center.x,arena.y+arena.h-60*ui},18*ui,DIM,.5,21);
    } else if client && local_id==0 {
        view_overlay(arena,140);
        msg:=ifx sess.client_authenticated then "Arena is full - spectating" else tprint("Connecting to %:%",to_string(address.data),port);
        text(msg,center+F.Vector2.{0,-20*ui},28*ui,WHITE,.5,21); text("ESC  back to menu",center+F.Vector2.{0,64*ui},16*ui,DIM,.5,21);
        for i:0..2 { t:=.5+.5*sin(view.time*5-cast(float32)i*.8); c:=NEON; c.a=cast(u8)(255*(.4+.6*t)); view_ui_dot(.{center.x+(cast(float32)i-1)*22*ui,center.y+32*ui},(4+3*t)*ui,c); }
    }
}
view_render :: () {
    view.label_id=0; w:=cast(float32)game_width; h:=cast(float32)game_height; ui:=clamp(min(w/1280,h/800),cast(float32).6,cast(float32)3);
    _=G2.rect(*game_canvas,.{0,0,w,h},BG); _=G2.circle_gradient(*game_canvas,.{w/2,h*.45},max(w,h)*.75,64,BG_GLOW,BG);
    top:=92*ui; bottom:=46*ui; pad:=28*ui; view.scale=min((w-pad*2)/1200,(h-top-bottom)/680);
    view.origin=.{(w-1200*view.scale)/2,top+(h-top-bottom-680*view.scale)/2};
    if view.shake>0 view.origin+=F.Vector2.{sin(view.time*93),cos(view.time*71)}*(view.shake*view.shake*7*ui);
    reg:=view_registry(); local_id:=local_player(); m:=find_match(reg);
    G2.push_matrix_trs(*game_canvas,view.origin,.{view.scale,view.scale},0); draw_arena(m); draw_coins();
    for p:view.particles { t:=p.life/p.max_life; _=G2.circle(*game_canvas,v2(p.pos),p.size*(.4+.6*t),8,fade(p.color,t)); }
    draw_players(reg,local_id); G2.pop_matrix(*game_canvas); draw_labels(reg,local_id);
    for p:view.popups {
        label:=tprint("%%",ifx p.value>=0 then "+" else "",p.value); color:=ifx p.value>0 then (ifx p.value>1 then GEM else GOLD) else DANGER;
        at:=to_screen(p.pos); size:=24*view.scale*(1+.3*max(cast(float32)0,p.life-.7)/.3);
        text(label,at+F.Vector2.{1,2},size,fade(INK,p.life*.6),.5); text(label,at,size,fade(color,p.life),.5);
    }
    draw_hud(reg,m,local_id,w,h,ui);
}
