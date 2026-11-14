#import "Basic";
FILE :: #import "File";
NOTES :: #import "kit/tools/scene_notes";
main :: () {
    path::"build/tests/notes-regression.json";
    assert(FILE.make_directory_if_it_does_not_exist("build/tests",true));
    // This file belongs exclusively to this regression, never to the editor.
    _=FILE.file_delete(path);
    s:NOTES.Session; assert(NOTES.init(*s,path)==.None); defer NOTES.dispose(*s);
    id,error:=NOTES.add(*s,.{scene="regression",text="中文原子保存",has_position=true,position=.{1,2,3}},true); assert(error==.None);
    assert(NOTES.undo(*s)==.None && NOTES.all(*s).count==0); assert(NOTES.redo(*s)==.None && NOTES.all(*s).count==1); assert(NOTES.save(*s)==.None);
    reader:NOTES.Session; assert(NOTES.init(*reader,path)==.None); defer NOTES.dispose(*reader);
    note,found:=NOTES.find(*reader,id); assert(found && note.text=="中文原子保存");
    assert(NOTES.resolve(*reader,id,"external result")==.None); assert(NOTES.save(*reader)==.None);
    disk,ok:=FILE.read_entire_file(path); assert(ok); defer free(disk.data);
    assert(NOTES.save(*s)==.External_Change,"External edits must never be overwritten");
    after,read_ok:=FILE.read_entire_file(path); assert(read_ok && disk==after); free(after.data);
    assert(NOTES.all(*s).count==1 && NOTES.all(*s)[0].status==NOTES.PENDING);
    _=FILE.file_delete(path); print("notes_regression: PASS (UTF-8, save, undo/redo, external conflict)\n");
    absolute:=FILE.get_absolute_path("build/tests/notes-absolute.json"); defer free(absolute.data);
    _=FILE.file_delete(absolute);
    absolute_session:NOTES.Session; assert(NOTES.init(*absolute_session,absolute)==.None); defer NOTES.dispose(*absolute_session);
    _,result:=NOTES.add(*absolute_session,.{scene="regression",text="absolute path fixture"},true);
    assert(result==.None); assert(NOTES.reload(*absolute_session)==.None);
    assert(NOTES.all(*absolute_session).count==1);
    _=FILE.file_delete(absolute);
}
