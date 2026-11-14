Scenery :: struct { items:[..]R3.Model_Item; buffer:R3.Model_Buffer; }
scenery:[6]Scenery;
hash :: (input:u32)->float32 {
    x:=input; x^=x>>16; x=cast,trunc(u32)(cast(u64)x*0x7feb352d); x^=x>>15; x=cast,trunc(u32)(cast(u64)x*0x846ca68b); x^=x>>16; return cast(float32)(x&0xffffff)/16777216;
}
terrain_height :: (x,z:float32)->float32 {
    dx:=(x+4.7)/3.1; dz:=(z-4)/2.8; r:=sqrt(sqrt(dx*dx*dx*dx+dz*dz*dz*dz)); if r>=1.14 return 0; if r<=.56 return -.95;
    angle:=atan2(dz,dx); edge:=r+.022*sin(angle*5+.7)+.014*sin(angle*9-.3); u:=clamp((edge-.60)/.50,0,1); return -.95*(1-u*u*(3-2*u));
}
pond_contains :: (x,z:float32,margin:float32=0)->bool { dx:=(x+4.7)/(3.1+margin); dz:=(z-4)/(2.8+margin); return dx*dx*dx*dx+dz*dz*dz*dz<1; }
quad :: ()->DA.Dasset_Primitive {
    p:DA.Dasset_Primitive; p.vertices=NewArray(4,DA.Dasset_Vertex); p.indices=NewArray(6,u32);
    for v,i:W.Vec3.[.{-.5,-.5,0},.{.5,-.5,0},.{.5,.5,0},.{-.5,.5,0}] p.vertices[i]=.{position=.[v.x,v.y,v.z],normal=.[0,0,1],uv=.[v.x+.5,.5-v.y],tangent=.[1,0,0,1]};
    for v,i:u32.[0,1,2,0,2,3] p.indices[i]=v; return p;
}
faceted :: (wind:bool)->DA.Dasset_Primitive {
    source:=sphere(6,9); defer primitive_free(*source); p:DA.Dasset_Primitive; p.vertices=NewArray(source.indices.count,DA.Dasset_Vertex); p.indices=NewArray(source.indices.count,u32);
    for tri:0..source.indices.count/3-1 {
        a:=source.vertices[source.indices[tri*3]].position; b:=source.vertices[source.indices[tri*3+1]].position; c:=source.vertices[source.indices[tri*3+2]].position;
        va:=W.Vec3.{a[0],a[1],a[2]}; vb:=W.Vec3.{b[0],b[1],b[2]}; vc:=W.Vec3.{c[0],c[1],c[2]}; n:=cross(vb-va,vc-va); if length(n)<.00001 n=normalize(va+vb+vc); else n=normalize(n); if dot(n,va)<0 n=-n;
        for j:0..2 { i:=tri*3+j; p.vertices[i]=source.vertices[source.indices[i]]; p.vertices[i].normal=.[n.x,n.y,n.z]; if wind p.vertices[i].tangent[3]=-2; p.indices[i]=cast(u32)i; }
    } return p;
}
grass_mesh :: ()->DA.Dasset_Primitive {
    p:DA.Dasset_Primitive; p.vertices=NewArray(18,DA.Dasset_Vertex); p.indices=NewArray(18,u32);
    for blade:0..2 { a:=cast(float32)blade*2.1; x:=cos(a); z:=sin(a); points:[3][3]float32=.[.[-x*.28,0,-z*.28],.[x*.28,0,z*.28],.[z*.28,.65+cast(float32)blade*.17,-x*.28]];
        for side:0..1 for j:0..2 { i:=blade*6+side*3+j; index:=ifx side==0 then j else 2-j; p.vertices[i]=.{position=points[index],normal=.[0,1,0],uv=.[0,points[index][1]],tangent=.[1,0,0,-1]}; p.indices[i]=cast(u32)i; }
    } return p;
}
trunk_mesh :: ()->DA.Dasset_Primitive {
    p:DA.Dasset_Primitive; p.vertices=NewArray(108,DA.Dasset_Vertex); p.indices=NewArray(108,u32);
    for ring:0..2 for side:0..5 {
        y0:=cast(float32)ring/3; y1:=cast(float32)(ring+1)/3; r0:=.19-y0*.09; r1:=.19-y1*.09; a:=cast(float32)side*3.14159265/3; b:=cast(float32)(side+1)*3.14159265/3;
        points:[4][3]float32=.[.[cos(a)*r0+y0*y0*.18,y0,sin(a)*r0],.[cos(b)*r0+y0*y0*.18,y0,sin(b)*r0],.[cos(b)*r1+y1*y1*.18,y1,sin(b)*r1],.[cos(a)*r1+y1*y1*.18,y1,sin(a)*r1]];
        for index,j:int.[0,1,2,0,2,3] { i:=(ring*6+side)*6+j; p.vertices[i]=.{position=points[index],normal=.[cos((a+b)*.5),.1,sin((a+b)*.5)],tangent=.[1,0,0,1]}; p.indices[i]=cast(u32)i; }
    } return p;
}
flower_mesh :: ()->DA.Dasset_Primitive {
    p:DA.Dasset_Primitive; p.vertices=NewArray(102,DA.Dasset_Vertex); p.indices=NewArray(102,u32); at:=0;
    flower_triangle(*p,*at,.{-.025,0,0},.{.025,0,0},.{0,.75,0},0); flower_triangle(*p,*at,.{0,.3,0},.{-.22,.44,.06},.{0,.5,0},0);
    for petal:0..4 { a:=cast(float32)petal*6.2831853/5; center:=W.Vec3.{cos(a)*.19,.73,sin(a)*.19}; left:=center+W.Vec3.{-sin(a)*.12,.03,cos(a)*.12}; right:=center-W.Vec3.{-sin(a)*.12,-.03,cos(a)*.12}; tip:=W.Vec3.{cos(a)*.34,.81,sin(a)*.34};
        flower_triangle(*p,*at,.{0,.74,0},left,tip,1); flower_triangle(*p,*at,.{0,.74,0},tip,right,1); b:=a+6.2831853/5; flower_triangle(*p,*at,.{0,.8,0},.{cos(a)*.09,.8,sin(a)*.09},.{cos(b)*.09,.8,sin(b)*.09},.5);
    } return p;
}
flower_triangle :: (p:*DA.Dasset_Primitive,at:*int,a,b,c:W.Vec3,palette:float32) {
    for v:W.Vec3.[a,b,c,c,b,a] { p.vertices[at.*]=.{position=.[v.x,v.y,v.z],normal=.[0,1,0],uv=.[palette,0],tangent=.[1,0,0,-3]}; p.indices[at.*]=cast(u32)at.*; at.*+=1; }
}
terrain_mesh :: ()->DA.Dasset_Primitive {
    N::83; p:DA.Dasset_Primitive; p.vertices=NewArray(N*N,DA.Dasset_Vertex); p.indices=NewArray((N-1)*(N-1)*6,u32); xs,zs:[N]float32; xs[0]=-120; zs[0]=-120; xs[N-1]=120; zs[N-1]=120;
    for i:0..80 { q:=cast(float32)i/80*2-1; xs[i+1]=-4.7+q*3.1*1.3; zs[i+1]=4+q*2.8*1.3; }
    for z:0..N-1 for x:0..N-1 {
        px:=xs[x]; pz:=zs[z]; normal:=normalize(W.Vec3.{terrain_height(px-.01,pz)-terrain_height(px+.01,pz),.02,terrain_height(px,pz-.01)-terrain_height(px,pz+.01)});
        p.vertices[z*N+x]=.{position=.[px,terrain_height(px,pz),pz],normal=.[normal.x,normal.y,normal.z],uv=.[px,pz],tangent=.[1,0,0,1]};
        if x<N-1 && z<N-1 { a:=cast(u32)(z*N+x); for index,j:u32.[a,a+1,a+N+1,a,a+N+1,a+N] p.indices[(z*(N-1)+x)*6+j]=index; }
    } return p;
}
scenery_add :: (kind:int,pos,size:W.Vec3,color:[4]float32,yaw:float32=0) { array_add(*scenery[kind].items,.{world=place(pos,size,yaw),tint=color}); }
collider_add :: (pos,size:W.Vec3,yaw:float32=0) { array_add(*colliders,.{center=pos,half=size*.5,axis_x=.{cos(yaw),0,sin(yaw)},axis_z=.{-sin(yaw),0,cos(yaw)}}); }
blocked :: (pos:W.Vec3,margin:float32)->bool { for b:colliders { if b.center.y-b.half.y>pos.y+.4 continue; _,depth:=box_contact(b,pos,margin); if depth>0 return true; } return false; }
scenery_build :: () {
    collider_add(.{-.8,.575,1.4},.{5,1.15,.6});
    for row:0..1 for col:0..5 { v:=hash(cast(u32)(row*6+col+1)); x:=-2.88+cast(float32)col*.835; y:=.24+cast(float32)row*.48;
        scenery_add(0,.{x,y,1.4},.{.815,.46,.60},.[.78*(.93+v*.12),.72*(.93+v*.12),.55*(.93+v*.12),1]);
    }
    for col:0..5 { x:=-2.88+cast(float32)col*.835; scenery_add(0,.{x,1.055,1.4},.{.83,.19,.76},.[.88,.82,.64,1]); if col%3==0 scenery_add(0,.{x,1.16,1.4},.{.45,.03,.45},.[.42,.56,.25,1]); }
    collider_add(.{0,.7,-13},.{44,1.4,8}); collider_add(.{0,1.5,-13},.{44,.2,8.2}); scenery_add(0,.{0,.7,-13},.{44,1.4,8},.[.63,.52,.36,1]); scenery_add(0,.{0,1.5,-13},.{44,.2,8.2},.[.47,.6,.28,1]);
    for i:0..29 scenery_add(0,.{-21+cast(float32)i*1.45,1.37,-8.98},.{1.3,.2,.18},.[.44,.56,.26,1]);
    rock_pos:=W.Vec3.[.{3,.12,3.4},.{3.5,.08,3.9},.{-4.6,.15,.92},.{6.4,.1,2.2}]; rock_size:=W.Vec3.[.{.7,.45,.55},.{.4,.3,.35},.{.8,.5,.6},.{.5,.35,.5}];
    for source,i:rock_pos { p:=source; angle:=float32.[.35,-.6,-.5,.8][i]; p.y+=terrain_height(p.x,p.z); scenery_add(2,p,rock_size[i]*.65,.[.59+cast(float32)i*.025,.61,.57,1],angle); collider_add(p,rock_size[i],angle); }
    for p,i:W.Vec3.[.{4.3,.4,-1.4},.{5.2,.4,-1.1},.{4.7,1.2,-1.3}] { angle:=float32.[.15,-.3,.5][i]; scenery_add(0,p,.{.8,.8,.8},.[.62,.4,.23,1],angle); collider_add(p,.{.8,.8,.8},angle);
        parent:=place(p,.{1,1,1},angle);
        for side:0..1 for edge:0..1 {
            z:float32=ifx side==0 then -.411 else .411; x:float32=ifx edge==0 then -.30 else .30;
            array_add(*scenery[0].items,.{world=W.matrix4_multiply(place(.{x,0,z},.{.095,.8,.035}),parent),tint=.[.85,.63,.34,1]});
            array_add(*scenery[0].items,.{world=W.matrix4_multiply(place(.{0,x,z},.{.8,.095,.035}),parent),tint=.[.85,.63,.34,1]});
        }
        for plank:0..2 array_add(*scenery[0].items,.{world=W.matrix4_multiply(place(.{cast(float32)(plank-1)*.26,.407,0},.{.24,.025,.78}),parent),tint=.[.77,.52,.27,1]});
    }
    trees:=W.Vec3.[.{-5.6,0,-3.4},.{6.2,0,-4.4},.{-8.2,0,1.6},.{8.6,0,.6},.{-10.5,0,-5.5},.{10.8,0,-6.2},.{1.8,0,-7},.{-14,0,-3},.{14,0,-2}];
    for p,i:trees {
        v:=hash(cast(u32)(i+100)); height:=1.75+v*.45; scenery_add(3,p,.{1.2,height,1.2},.[.37,.28,.19,1]); collider_add(p+W.Vec3.{0,height*.5,0},.{.48,height,.48});
        for crown:0..2 { scale:=ifx crown==1 then W.Vec3.{.95,1.05,.9} else W.Vec3.{1.05,.82,1}; scale=scale*(.91+v*.25); pos:=p+W.Vec3.{cast(float32)(crown-1)*.62,height+.30+(ifx crown==1 then cast(float32).62 else 0),cast(float32)(crown%2)*.25};
            scenery_add(1,pos,scale,.[.38+v*.12+cast(float32)crown*.035,.56+v*.1,.22+v*.06,1]); collider_add(pos,scale*2);
        }
    }
    for i:0..8 { p:=W.Vec3.{-25+cast(float32)i*6,0,-24-hash(cast(u32)(i+800))*4}; scenery_add(3,p,.{1.5,2.6,1.5},.[.35,.27,.19,1]); scenery_add(1,p+W.Vec3.{0,3,0},.{2.3,1.5+hash(cast(u32)(i+910))*.6,2},.[.4,.54,.27,1]); }
    for i:0..1199 {
        seed:=cast(u32)(i*11); x:=-15+hash(seed+1)*30; z:=-8.4+hash(seed+2)*19; path:=2.8*exp(-pow((z-1)/3,cast(float32)2))+.55*sin(.38*z);
        if abs(x-path)<1.42 || pond_contains(x,z,.3) || blocked(.{x,0,z},.22) continue;
        v:=hash(seed+3); angle:=hash(seed+5)*6.2831853; p:=W.Vec3.{x,terrain_height(x,z),z};
        if hash(seed+4)<.7 scenery_add(4,p,.{.22+v*.22,.18+v*.23,.22+v*.22},.[.4+v*.12,.55+v*.1,.2+v*.06,1],angle);
        else if hash(seed+6)>.35 { size:=.44+v*.24; color:=ifx v<.33 then float32.[1,.87,.52,1] else ifx v<.66 then float32.[.83,.64,.95,1] else float32.[1,.67,.43,1]; scenery_add(5,p,.{size,size,size},color,angle); }
    }
    for i:0..21 {
        v:=hash(cast(u32)(i+2100)); if v<.23 continue;
        angle:=cast(float32)i*6.2831853/22; x:=cos(angle); z:=sin(angle); d:=sqrt(sqrt(x*x*x*x+z*z*z*z));
        p:=W.Vec3.{-4.7+x/d*3.1*(1.08+v*.07),0,4+z/d*2.8*(1.08+v*.07)}; p.y=terrain_height(p.x,p.z);
        if !blocked(p,.35) scenery_add(4,p,.{.32+v*.12,.50+v*.35,.32+v*.12},.[.32+v*.06,.48+v*.08,.22,1],angle+v);
    }
    for *b,i:scenery { assert(R3.model_buffer_init(*b.buffer,ifx i==5 then flower_mat else toon,b.items.count,tprint("scenery %",i))==""); assert(R3.model_buffer_upload(*b.buffer,b.items)); static_count+=b.items.count; }
}
record_player :: () {
    speed:=sqrt(player.vel.x*player.vel.x+player.vel.z*player.vel.z); stride:float32=ifx player.grounded then sin(player.gait)*min(speed/4.2,cast(float32)1) else 0; bob:=abs(stride)*.035;
    Part :: struct { pos,size:W.Vec3; color:[4]float32; }
    parts:=Part.[.{.{0,.77+bob,0},.{.30,.46,.25},.[.60,.38,.72,1]},.{.{0,1.38+bob,-.02},.{.29,.30,.28},.[1,.84,.72,1]},.{.{0,1.49+bob,.07},.{.32,.28,.28},.[.9,.26,.28,1]},
        .{.{-.17,.16+max(cast(float32)0,stride)*.12,-stride*.18},.{.13,.16,.21},.[.24,.21,.36,1]},.{.{.17,.16+max(cast(float32)0,-stride)*.12,stride*.18},.{.13,.16,.21},.[.24,.21,.36,1]},
        .{.{-.34,.79+bob,stride*.16},.{.11,.27,.12},.[.66,.43,.77,1]},.{.{.34,.79+bob,-stride*.16},.{.11,.27,.12},.[.66,.43,.77,1]},
        .{.{-.10,1.42+bob,-.275},.{.035,.05,.025},.[.13,.14,.22,1]},.{.{.10,1.42+bob,-.275},.{.035,.05,.025},.[.13,.14,.22,1]}];
    items:[9]R3.Model_Item; transform:=place(player.pos,.{1,1,1},player.yaw); for p,i:parts items[i]=.{world=W.matrix4_multiply(place(p.pos,p.size),transform),tint=p.color};
    assert(R3.models(*renderer,*ball,hero,items)==.None); assert(R3.models(*renderer,*ball,sun,items)==.None);
}
