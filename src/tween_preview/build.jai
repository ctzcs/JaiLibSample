#import "Basic";
FILE :: #import "File";
C :: #import "Compiler";
#run {
    target,ok:=FILE.read_entire_file("../../build/tween-preview-target.txt"); assert(ok);
    w:=C.compiler_create_workspace("tween preview module"); options:=C.get_build_options(w);
    options.output_type=.DYNAMIC_LIBRARY; options.output_executable_name=target; options.output_path="../../"; options.append_executable_filename_extension=false;
    options.import_path=.["../../../JaiLib"];
    C.set_build_options(options,w); C.add_build_file("module.jai",w);
    failed:=false; C.compiler_begin_intercept(w);
    while true { message:=C.compiler_wait_for_message(); if message.kind==.ERROR failed=true; if message.kind==.COMPLETE break; }
    C.compiler_end_intercept(w); if failed exit(1);
}
main :: () {}
