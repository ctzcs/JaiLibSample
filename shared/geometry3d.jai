sphere :: (rings: int = 32, segments: int = 48) -> DA.Dasset_Primitive {
    p: DA.Dasset_Primitive;
    p.vertices = NewArray((rings+1)*(segments+1), DA.Dasset_Vertex);
    p.indices = NewArray(rings*segments*6, u32);
    for r: 0..rings for n: 0..segments {
        theta := cast(float32) r / cast(float32) rings * 3.14159265;
        phi := cast(float32) n / cast(float32) segments * 6.2831853;
        normal: [3] float32 = .[sin(theta)*cos(phi), cos(theta), sin(theta)*sin(phi)];
        p.vertices[r*(segments+1)+n] = .{position=normal, normal=normal,
            uv=.[cast(float32) n / cast(float32) segments,cast(float32) r / cast(float32) rings], tangent=.[-sin(phi),0,cos(phi),1]};
    }
    for r: 0..rings-1 for n: 0..segments-1 {
        a := cast(u32) (r*(segments+1)+n); seg := cast(u32) segments;
        offsets: [6] u32 = .[a,a+seg+2,a+1,a,a+seg+1,a+seg+2];
        for index, j: offsets p.indices[(r*segments+n)*6+j] = index;
    }
    return p;
}
primitive_free :: (p: *DA.Dasset_Primitive) { free(p.vertices.data); free(p.indices.data); p.* = .{}; }
cube :: () -> DA.Dasset_Primitive {
    p: DA.Dasset_Primitive;
    p.vertices=NewArray(24,DA.Dasset_Vertex); p.indices=NewArray(36,u32);
    corners: [8][3] float32 = .[.[-0.5,-0.5,-0.5],.[0.5,-0.5,-0.5],.[0.5,0.5,-0.5],.[-0.5,0.5,-0.5],.[-0.5,-0.5,0.5],.[0.5,-0.5,0.5],.[0.5,0.5,0.5],.[-0.5,0.5,0.5]];
    faces: [6][4] int=.[.[0,3,2,1],.[4,5,6,7],.[0,1,5,4],.[3,7,6,2],.[0,4,7,3],.[1,2,6,5]];
    normals: [6][3] float32=.[.[0,0,-1],.[0,0,1],.[0,-1,0],.[0,1,0],.[-1,0,0],.[1,0,0]];
    for face,i: faces {
        for corner,j: face p.vertices[i*4+j]=.{position=corners[corner],normal=normals[i],tangent=.[1,0,0,1],uv=.[cast(float32) (j%2),cast(float32) (j/2)]};
        for offset,j: int.[0,2,1,0,3,2] p.indices[i*6+j]=cast(u32) (i*4+offset);
    }
    return p;
}
