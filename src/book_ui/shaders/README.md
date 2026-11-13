# Book shader

Copied from `olib_sample/src/book_ui/shaders/Book.hlsl` and its compiled outputs.
The sample embeds the DXIL and SPIR-V vertex/fragment binaries at compile time;
it does not require a shader compiler or runtime asset path.

Vertex layout: position float3, normal float3, UV float2, color float4.
Vertex uniform slot 0 contains the packed world-view-projection and world matrices.
Fragment sampler slots 0 and 1 contain the front and back page textures.

jfoster uses clockwise raster front faces. `renderer.jai` reverses the source
sheet triangle winding so this shader samples the intended page side.
