// olib_sample/src/feature 的 Jai 版本：图集打包 + 图像编解码往返。
// olib 的 MsdfFontMake(img, json) 直接吃内存图；JaiLib 的 msdf_font_load_bytes
// 需要一份真实的 MSDF 图集（PNG + JSON 度量），示例不伪造那份数据，
// 改在这里验证 packer 产物能被 QOI/PNG 编解码器原样读回。
#import "Basic";
F :: #import "foster";

main :: () {
    packer := F.packer_create(.{ Trim = false, Padding = 0, PowerOfTwo = true });
    img := F.image_create(8, 8, F.Color_Transparent);
    F.image_set_pixel(*img, 1, 1, F.Color_White);
    F.packer_add(*packer, "one", img.Data, img.Width, img.Height);

    img2 := F.image_create(4, 4, F.Color_Red);
    F.packer_add(*packer, "two", img2.Data, img2.Width, img2.Height);
    F.packer_pack(*packer);
    print("packed pages: %, entries: %, first page: %x%\n", packer.Pages.count,
        packer.Output.count, packer.Pages[0].Width, packer.Pages[0].Height);

    page := packer.Pages[0];
    qoi := F.image_encode_qoi(page);
    print("qoi: % bytes, header ok: %\n", qoi.count, F.qoi_is_format(qoi));
    decoded_qoi := F.qoi_decode(qoi);
    print("qoi roundtrip size: %x%, pixel(1,1) alpha: %\n", decoded_qoi.Width,
        decoded_qoi.Height, F.image_pixel(*decoded_qoi, 1, 1).a);
    F.image_destroy(*decoded_qoi);
    free(qoi.data);

    png := F.image_encode_png(page);
    decoded_png := F.image_decode(png);
    print("png: % bytes, roundtrip size: %x%\n", png.count, decoded_png.Width, decoded_png.Height);
    F.image_destroy(*decoded_png);
    free(png.data);

    F.packer_destroy(*packer);
    F.image_destroy(*img);
    F.image_destroy(*img2);
}
