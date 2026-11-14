#import "Basic";
LAB :: #import "kit/tools/tween_preview";
T :: #import "core/tween";
M :: #import "Math";
F :: #import "foster";
IG :: #import "thirdparty/imgui";
#load "motion.jai";
#program_export "preview_catalog"
preview_catalog :: (ctx:*#Context,imgui:*IG.ImGuiContext,data:**LAB.Case,count:*s64) #c_call {
    push_context ctx.* {
    IG.SetCurrentContext(imgui); catalog_init(); data.*=cases.data; count.*=cases.count; }
}
