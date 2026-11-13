// olib_sample/src/spatial 的 Jai 版本：foster/spatial 的几何与变换。
#import "Basic";
M :: #import "Math";
using M;
F :: #import "foster";

main :: () {
    print("point length: %\n", F.point2_length(.{ 3, 4 }));

    r := F.Rect_Int.{ 0, 0, 10, 10 };
    print("contains: %\n", F.rect_int_contains_point(r, .{ 4, 4 }));
    overlap_rect := F.rect_int_get_intersection(r, F.Rect_Int.{ 5, 5, 10, 10 });
    print("intersection area: %\n", overlap_rect.w * overlap_rect.h);

    hit, at := F.line_intersects_line(.{ 0, 0 }, .{ 10, 10 }, .{ 0, 10 }, .{ 10, 0 });
    print("line intersection: % at (%, %)\n", hit, at.x, at.y);

    print("cardinal point: (%, %)\n", F.cardinal_point(.LEFT).x, F.cardinal_point(.LEFT).y);

    print("rect/line: %\n", F.line_intersects_rect(.{ -2, 5 }, .{ 12, 5 }, F.Rect.{ 0, 0, 10, 10 }));

    overlap, pushout := F.circle_overlaps(F.Circle.{ .{ 0, 0 }, 5 }, F.Circle.{ .{ 8, 0 }, 5 });
    print("circle overlap: % pushout (%, %)\n", overlap, pushout.x, pushout.y);

    transform := F.Transform.{ position = .{ 10, 20 }, scale = .{ 2, 2 }, rotation = 0 };
    moved := F.transform_apply(transform, .{ 1, 1 });
    print("transform: (%, %)\n", moved.x, moved.y);

    print("red rgba: % format size: % key: %\n", F.color_rgba(F.Color_Red),
        F.texture_format_size(.COLOR), F.Keys.A);

    print("ease: %, clamp: %\n", F.ease_quad_inout(0.25), F.calc_clamp_f(1.5, 0, 1));

    poly: F.Polygon;
    F.polygon_add(*poly, .{ 0, 0 });
    F.polygon_add(*poly, .{ 10, 0 });
    F.polygon_add(*poly, .{ 10, 10 });
    F.polygon_add(*poly, .{ 0, 10 });
    print("polygon: % %\n", F.polygon_contains(*poly, .{ 5, 5 }), F.polygon_area(*poly));
    F.polygon_destroy(*poly);

    rng := F.rng_create(123);
    print("rng: % %\n", F.rng_range_i(*rng, 0, 10), F.rng_chance(*rng, 1));
    print("qoi header: %\n", F.qoi_is_format(cast([] u8) "qoif"));
}
