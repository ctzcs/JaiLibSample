#load "../../shared/scene3d.jai";
MU :: #import "core/meshutil";
G :: #import "kit/gizmo";
STR :: #import "String";
source: DA.Dasset_Primitive;
positions: [][3] float32;
current_indices: [] u32;
mesh: F.Mesh;
material: *MAT.Material;
wire: G.Renderer3D;
edges: G.Wireframe;
statistics: MU.Stats;
level: int;
solid: bool = true;
wireframe: bool = true;
xray: bool;
mesh_center: W.Vec3;
mesh_radius: float32;
fit_camera :: () { h.focus=mesh_center; h.distance=max(cast(float32)0.3,mesh_radius*2.4); h.yaw=0.35; h.pitch=0.3; }
mesh_stats :: () -> string {
    return tprint("MESHVIEW / LOD %\n% triangles / % seams / % borders / % non-manifold\nA/S: LOD   W: wire   M: solid   X: xray   F: fit",level,statistics.triangles,statistics.seam_edges,statistics.border_edges,statistics.non_manifold_edges);
}
main :: () { scene_run("meshview"); }
scene_start :: () {
    scene_hud_text=mesh_stats;
    scene_register("src/meshview/shaders/Compiled"); material = scene_material("MeshView");
    assert(G.renderer3d_init(*wire, F.App.device));
    source = sphere(48,96);
    // Exact seam/pole positions plus a deliberate hole make topology visible.
    for *v, i: source.vertices {
        r := i/97; n := i%97;
        theta := cast(float32) r/48 * cast(float32) M.PI;
        phi := cast(float32) (n%96)/96 * cast(float32) (M.PI*2);
        radius := 1+0.12*sin(5*phi)*sin(3*theta);
        v.position = .[sin(theta)*cos(phi)*radius,cos(theta)*radius,sin(theta)*sin(phi)*radius];
        if r == 0 || r == 48 v.position = .[0,ifx r == 0 then 1 else -1,0];
    }
    written := 0;
    for r: 0..47 for n: 0..95 {
        if r >= 22 && r < 25 && n >= 22 && n < 26 continue;
        a := cast(u32) (r*97+n);
        if r > 0 { for index: u32.[a,a+97,a+1] { source.indices[written] = index; written += 1; } }
        if r < 47 { for index: u32.[a+1,a+97,a+98] { source.indices[written] = index; written += 1; } }
    }
    source.indices.count = written;
    for arg: get_command_line_arguments() if STR.ends_with(arg, ".dasset") {
        bytes, ok := FILE.read_entire_file(arg); assert(ok); defer free(bytes.data);
        model, error := DA.dasset_read(cast([] u8) bytes); assert(error == .None);
        defer DA.dasset_model_dispose(*model);
        primitive_free(*source);
        nv, ni: int;
        for p: model.primitives { nv += p.vertices.count + p.skin_vertices.count; ni += p.indices.count; }
        source.vertices = NewArray(nv, DA.Dasset_Vertex); source.indices = NewArray(ni,u32);
        vi, ii: int;
        for p: model.primitives {
            base := vi;
            for v: p.vertices { source.vertices[vi] = v; vi += 1; }
            for v: p.skin_vertices { source.vertices[vi] = .{position=v.position,normal=v.normal,uv=v.uv,tangent=v.tangent}; vi += 1; }
            for index: p.indices { source.indices[ii] = cast(u32) base + index; ii += 1; }
        }
    }
    assert(source.vertices.count>0 && source.indices.count>=3,"Model contains no triangles");
    low:=source.vertices[0].position; high:=low;
    for v: source.vertices for axis: 0..2 { low[axis]=min(low[axis],v.position[axis]); high[axis]=max(high[axis],v.position[axis]); }
    mesh_center=.{(low[0]+high[0])*0.5,(low[1]+high[1])*0.5,(low[2]+high[2])*0.5};
    dx:=high[0]-low[0]; dy:=high[1]-low[1]; dz:=high[2]-low[2];
    mesh_radius=sqrt(dx*dx+dy*dy+dz*dz)*0.5;
    positions = NewArray(source.vertices.count,[3] float32);
    for v,i: source.vertices positions[i] = v.position;
    set_level(0); fit_camera();
    if has_arg("wire") solid=false;
    if has_arg("solid") wireframe=false;
    xray=has_arg("xray");
}
set_level :: (next: int) {
    if next < 0 || next > 16 return;
    indices: [] u32;
    if next == 0 { indices = NewArray(source.indices.count,u32); for v,i: source.indices indices[i]=v; }
    else {
        error: float32; ok: bool;
        target:=max(3,source.indices.count >> next);
        indices,error,ok = MU.simplify(positions,source.indices,target,0.05);
        if !ok || indices.count<3 { free(indices.data); print("MeshView: simplification limit reached\n"); return; }
        if next > level && indices.count >= current_indices.count { free(indices.data); return; }
    }
    R3.clear(*h.renderer); R3.mesh_dispose(*mesh); G.wireframe_destroy(*edges); free(current_indices.data);
    current_indices=indices; level=next;
    vertices,compact_ok:=MU.compact(source.vertices,indices); assert(compact_ok); defer free(vertices.data);
    draw_positions:=NewArray(vertices.count,[3]float32); defer free(draw_positions.data);
    for v,i:vertices draw_positions[i]=v.position;
    p := source; p.indices=indices; p.vertices=vertices;
    assert(R3.mesh_upload(*mesh,F.App.device,*p));
    topology,ok := MU.edges(draw_positions,indices); assert(ok); defer free(topology.data);
    assert(G.wireframe_init(*edges,F.App.device,draw_positions,topology));
    // Foster's draw path requires an index buffer even for the six expanded corners.
    F.mesh_set_indices(edges.mesh, u32.[0,1,2,3,4,5]);
    statistics=MU.stats(draw_positions,indices);
    F.window_set_title(F.App.window,tprint("MeshView | LOD % / % triangles / % vertices / % seams / % borders | A/S LOD, W wire, M solid, X xray",level,statistics.triangles,vertices.count,statistics.seam_edges,statistics.border_edges));
    print("MeshView level %: % triangles, % seams, % borders, % non-manifold\n",level,statistics.triangles,statistics.seam_edges,statistics.border_edges,statistics.non_manifold_edges);
}
scene_update :: () {
    keys:=F.input_keyboard(F.App.input);
    if F.keyboard_pressed(keys,.F) fit_camera();
    if F.keyboard_pressed(keys,.W) wireframe=!wireframe;
    if F.keyboard_pressed(keys,.M) solid=!solid;
    if F.keyboard_pressed(keys,.X) xray=!xray;
    if F.keyboard_pressed(keys,.S) || F.keyboard_pressed(keys,.RIGHT) set_level(level+1);
    if F.keyboard_pressed(keys,.A) || F.keyboard_pressed(keys,.LEFT) set_level(level-1);
    if (h.shot || h.smoke) && h.frame==5 { scene_capture("meshview-original"); set_level(3); }
}
scene_draw :: (view: R3.View) {
    if solid { assert(R3.model(*h.renderer,*mesh,material,W.MATRIX4_IDENTITY)==.None); assert(R3.submit(*h.renderer,view)==.None); }
    if wireframe {
        style:=G.DEFAULT_WIREFRAME_STYLE; if xray style.hidden_alpha=1;
        G.wireframe_draw(*wire,view.target,*h.camera,*edges,W.MATRIX4_IDENTITY,.{0,0,cast(float32) h.target.Width,cast(float32) h.target.Height},1,style);
    }
}
scene_check :: () {
    assert(statistics.invalid_indices==0 && current_indices.count<=source.indices.count);
    assert(h.focus.x==mesh_center.x && h.focus.y==mesh_center.y && h.focus.z==mesh_center.z);
    assert(h.distance>=mesh_radius*2.39);
    pixels:=NewArray(h.target.Width*h.target.Height,F.Color); defer free(pixels.data);
    F.texture_get_data(F.target_texture(h.target),pixels);
    changed:=0; for pixel:pixels if pixel!=F.Color.{31,38,51,255} changed+=1;
    assert(changed>1000,"Mesh geometry is outside the camera or failed to draw");
}
scene_stop :: () {
    R3.mesh_dispose(*mesh); G.wireframe_destroy(*edges); G.renderer3d_destroy(*wire);
    primitive_free(*source); free(positions.data); free(current_indices.data);
}
