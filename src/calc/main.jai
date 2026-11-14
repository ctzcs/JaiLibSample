// olib_sample/src/calc 的 Jai 版本：foster/utility/calc 的数学与三角化。
// 名称按 JaiLib 的 <模块>_<动作> 约定（olib 的 Smallest/Largest 在这里是
// calc_clamp_f / calc_lerp 等同一组工具）。
#import "Basic";
M :: #import "Math";
using M;
F :: #import "foster";

main :: () {
    assert(F.calc_lerp(0,10,0.25)==2.5 && F.calc_clamp_f(1.5,0,1)==1 && F.calc_map(5,0,10,0,100)==50);
    print("lerp: %, clamp: %, map: %\n", F.calc_lerp(0, 10, 0.25),
        F.calc_clamp_f(1.5, 0, 1), F.calc_map(5, 0, 10, 0, 100));

    points := F.Vector2.[ .{ 0, 0 }, .{ 2, 0 }, .{ 2, 2 }, .{ 0, 2 } ];
    indices := F.calc_triangulate(points);
    assert(indices.count==6);
    area:float32;
    for triangle:0..1 {
        a:=points[indices[triangle*3]]; b:=points[indices[triangle*3+1]]; c:=points[indices[triangle*3+2]];
        area+=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*0.5;
    }
    assert(area==4);
    print("triangulation: %", indices.count);
    for index: indices print(" %", index);
    print("\n");
    array_free(indices);

    rng := F.rng_create(123);
    print("rng: % %\n", F.rng_range_i(*rng, 0, 10), F.rng_chance(*rng, 1));

    poly: F.Polygon;
    for p: points F.polygon_add(*poly, p);
    print("polygon area: %\n", F.polygon_area(*poly));
    F.polygon_destroy(*poly);
    print("[calc] PASS\n");
}
