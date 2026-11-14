// Reference net_fps HUD primitives; Render2D geometry and Clay/MSDF text.
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
