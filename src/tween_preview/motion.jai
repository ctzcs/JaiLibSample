// Case definitions and source objects are project-owned. Every preview owns a copy.
TIMING :: T.Tween_Config.{duration=1.2,delay=0.25,transition=.EaseOutElastic,repeat_mode=.Once};
Card :: struct { id: LAB.Target_ID; alive: bool; size: M.Vector2; color: F.Color; }
Motion :: struct {
    card: Card; pose: LAB.Pose;
    x,y,rotation,scale: T.Tween(float32);
    value,velocity,bounce: float32;
}
cards: [2] Card;
targets: [2] LAB.Target;
channels: [4] LAB.Channel;
spring_channels: [2] LAB.Channel;
parameters,spring_parameters: [1] LAB.Parameter;
cases: [3] LAB.Case;
catalog_init :: () {
    cards=.[.{.{low=1},true,.{72,96},.{108,232,188,255}},.{.{high=1,low=42},true,.{100,140},.{245,184,100,255}}];
    targets=.[.{.{low=1},"Default card"},.{.{high=1,low=42},"Scene card #42 (copy)"}];
    channels=.[.{"position-x","Position X","px"},.{"position-y","Position Y","px"},.{"rotation","Rotation","rad"},.{"scale","Scale","x"}];
    spring_channels=.[.{"offset","Spring offset","px"},.{"velocity","Velocity","px/s"}];
    parameters=.[.{"duration","Fly-in duration",1.2,0.1,5}]; spring_parameters=.[.{"bounce","Bounce",0.65,0,0.95}];
    cases=.[
        .{id="card/fly-in",name="Card / Fly in",source="src/tween_preview/motion.jai",source_line=32,duration=6,targets=targets,channels=channels,parameters=parameters,create=create_card,destroy=destroy_motion,step=step_card,observe=observe_card,draw=draw_card},
        .{id="card/spring",name="Card / Spring",source="src/tween_preview/motion.jai",source_line=49,duration=4,targets=targets,channels=spring_channels,parameters=spring_parameters,create=create_spring,destroy=destroy_motion,step=step_spring,observe=observe_spring,draw=draw_card},
        .{id="card/hover",name="Card / Hover",source="src/tween_preview/motion.jai",source_line=62,duration=2,targets=array_view(targets,0,1),create=create_hover,destroy=destroy_motion,step=step_hover,observe=observe_hover}];
}
resolve_card :: (id: LAB.Target_ID) -> *Card { for *card: cards if card.alive && LAB.target_id_equal(card.id,id) return card; return null; }
lerp :: (a: float32,b: float32,t: float32) -> float32 { return a+(b-a)*t; }
create_card :: (user: *void,id: LAB.Target_ID,p: [] float64) -> *void {
    source:=resolve_card(id); if source==null return null;
    m:=New(Motion); m.card=source.*;
    config:=TIMING; config.duration=cast(float32) p[0];
    m.x=T.make_ex(cast(float32) -220,160,0,config,lerp); m.y=T.make_ex(cast(float32) 70,-40,0,config,lerp);
    m.rotation=T.make_ex(cast(float32) -0.45,0,0,.{duration=config.duration*0.7,delay=config.delay,transition=.EaseOut},lerp);
    m.scale=T.make_ex(cast(float32) 0.6,1,0,.{duration=config.duration*0.6,delay=config.delay+config.duration*0.4,transition=.EaseOutElastic},lerp);
    step_card(m,0,0); return m;
}
destroy_motion :: (instance: *void) { free(instance); }
step_card :: (instance: *void,dt: float64,elapsed: float64) {
    m:=cast(*Motion) instance; time:=cast(float32) elapsed;
    m.value=T.tween_get_value(*m.scale,time);
    m.pose=.{position=.{T.tween_get_value(*m.x,time),T.tween_get_value(*m.y,time)},size=.{m.card.size.x*m.value,m.card.size.y*m.value},rotation=T.tween_get_value(*m.rotation,time),color=m.card.color};
}
observe_card :: (instance: *void) -> LAB.Observation {
    m:=cast(*Motion) instance; o:=LAB.Observation.{pose=m.pose,has_pose=true};
    o.values[0]=m.pose.position.x; o.values[1]=m.pose.position.y; o.values[2]=m.pose.rotation; o.values[3]=m.value; return o;
}
create_spring :: (user: *void,id: LAB.Target_ID,p: [] float64) -> *void {
    source:=resolve_card(id); if source==null return null;
    m:=New(Motion); m.card=source.*; m.value=-160; m.bounce=cast(float32) p[0];
    m.pose=.{position=.{m.value,0},size=m.card.size,color=m.card.color}; return m;
}
step_spring :: (instance: *void,dt: float64,elapsed: float64) {
    m:=cast(*Motion) instance; m.value,m.velocity=T.spring(m.value,m.velocity,cast(float32) 0,0.8,m.bounce,cast(float32) dt);
    m.pose.position.x=m.value; m.pose.rotation=m.value/400;
}
observe_spring :: (instance: *void) -> LAB.Observation {
    m:=cast(*Motion) instance; o:=LAB.Observation.{pose=m.pose,has_pose=true}; o.values[0]=m.value; o.values[1]=m.velocity; return o;
}
create_hover :: (user: *void,id: LAB.Target_ID,p: [] float64) -> *void {
    source:=resolve_card(id); if source==null return null;
    m:=New(Motion); m.card=source.*; m.pose=.{size=m.card.size,color=m.card.color}; return m;
}
step_hover :: (instance: *void,dt: float64,elapsed: float64) {
    m:=cast(*Motion) instance; m.pose.position.y=T.approach(m.pose.position.y,cast(float32) -80,5,cast(float32) dt);
}
observe_hover :: (instance: *void) -> LAB.Observation { return .{pose=(cast(*Motion) instance).pose,has_pose=true}; }
draw_card :: (instance: *void,canvas: LAB.Canvas) {
    m:=cast(*Motion) instance; LAB.draw_pose(canvas,m.pose);
    badge:=m.pose; badge.size.x*=0.35; badge.size.y*=0.35; badge.color=.{45,65,80,255}; LAB.draw_pose(canvas,badge);
}
