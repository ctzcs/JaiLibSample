# Optional extended sample font

This is the older 525-glyph Noto Sans CJK SC MSDF atlas copied from olib_sample.
It remains available as a custom asset; active CJK samples now embed
`JaiLib/assets/fonts/msdf` (509 glyphs), with source and license records there.

The files in this directory retain their own OFL license and charset. They were
generated with msdf-atlas-gen 1.4 from NotoSansCJKsc-Regular.otf, source SHA-256
`2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`.
Keep PNG and JSON together. No default sample loads this directory at runtime.

```text
msdf-atlas-gen -font NotoSansCJKsc-Regular.otf -charset shared/msdf_font/charset.txt -type msdf -format png -size 48 -pxrange 8 -yorigin top -seed 0 -imageout shared/msdf_font/ui.png -json shared/msdf_font/ui.json
```
