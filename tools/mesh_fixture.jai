#import "Basic";
M :: #import "Math";
using M;
FILE :: #import "File";
DA :: #import "core/dasset";
#load "../shared/geometry3d.jai";
main :: () {
    model:DA.Dasset_Model;
    for i:0..1 {
        p:=cube();
        for *v:p.vertices { v.position[0]=v.position[0]*4+100+cast(float32)i*6; v.position[1]=v.position[1]*4+50; v.position[2]=v.position[2]*4-80; }
        array_add(*model.primitives,p);
    }
    bytes,ok:=DA.dasset_write(*model); assert(ok); defer array_free(bytes);
    assert(FILE.write_entire_file("build/meshview-offset.dasset",cast(string)bytes));
    DA.dasset_model_dispose(*model);
    print("mesh_fixture PASS\n");
}
