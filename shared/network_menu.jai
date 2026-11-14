// Shared connection form for the two network games, backed by Clay widgets.
menu_address,menu_port,menu_bots,menu_lag: [..]u8;
menu_input_checks:int;
menu_set :: (buffer:*[..]u8,value:string) { buffer.count=0; for c:value array_add(buffer,c); }
menu_text :: (buffer:[]u8)->string { return cast(string)buffer; }
network_menu_init :: () {
    menu_set(*menu_address,to_string(address.data)); menu_set(*menu_port,tprint("%",port));
    menu_set(*menu_bots,tprint("%",bots)); menu_set(*menu_lag,tprint("%",lag));
}
network_menu_dispose :: () { array_free(menu_address); array_free(menu_port); array_free(menu_bots); array_free(menu_lag); }
menu_number :: (bytes:[]u8,minimum,maximum:int)->(int,bool) {
    if bytes.count==0 || bytes.count>5 return 0,false;
    value:=0; for c:bytes { if c<48 || c>57 return 0,false; value=value*10+cast(int)c-48; }
    return value,value>=minimum && value<=maximum;
}
menu_connect :: (chosen:Mode) {
    p,ok_p:=menu_number(menu_port,1,65535); b,ok_b:=menu_number(menu_bots,0,7); l,ok_l:=menu_number(menu_lag,0,5000);
    if !ok_p || !ok_b || !ok_l || (chosen==.Client && menu_address.count==0) {
        message="Enter a valid address, port (1-65535), bots (0-7), and latency (0-5000)."; return;
    }
    address=.{}; for c,i:menu_address address[i]=c;
    port=cast(s32)p; bots=cast(s32)b; lag=cast(s32)l; mode=chosen; net_start();
}
network_menu :: (title:string) {
    width:=min(cast(float32)600,game_ui.width-32);
    CLAY.UI(game_panel("connection-panel",(game_ui.width-width)*.5,36,width,true),#code {
        game_label(title,30,game_theme.accent);
        game_label("PLAY WITH FRIENDS",14,game_theme.text_dim);
        game_label(message,15);
        game_label("Server address",14,game_theme.text_dim);
        UI.ui_text_input(*game_ui,*game_theme,"net-address",*menu_address,"127.0.0.1",width-32,127);
        CLAY.UI(UI.ui_row_decl(12),#code {
            column:=UI.ui_column_decl(6);
            CLAY.UI(column,#code { game_label("Port",14); UI.ui_text_input(*game_ui,*game_theme,"net-port",*menu_port,"7788",(width-56)/3,5); });
            CLAY.UI(column,#code { game_label("Bots",14); UI.ui_text_input(*game_ui,*game_theme,"net-bots",*menu_bots,"3",(width-56)/3,1); });
            CLAY.UI(column,#code { game_label("Latency (ms)",14); UI.ui_text_input(*game_ui,*game_theme,"net-lag",*menu_lag,"0",(width-56)/3,4); });
        });
        CLAY.UI(UI.ui_row_decl(12),#code { UI.ui_toggle(*game_ui,*game_theme,"net-enet",*use_enet); game_label("Use ENet transport"); });
        CLAY.UI(UI.ui_row_decl(12),#code {
            if UI.ui_button_ex(*game_ui,*game_theme,"net-host","Host",.Primary) menu_connect(.Host);
            if UI.ui_button(*game_ui,*game_theme,"net-join","Join") menu_connect(.Client);
            if UI.ui_button(*game_ui,*game_theme,"net-server","Server") menu_connect(.Server);
        });
        game_label("Host starts a match here. Join connects to another machine.",14,game_theme.text_dim);
    });
}
game_test_input :: () {
    if !has_arg("menu-test") return;
    if game_frame==1 || game_frame==2 game_test_click("net-address",game_frame==1);
    if game_frame==3 { assert(UI.ui_text_editing(*game_ui)); UI.ui_set_text_edit(*game_ui,.{text="w"}); F.keyboard_state_on_key(F.input_keyboard(F.App.input),cast(s32)F.Keys.W,true,F.App.time.elapsed); }
    if game_frame==4 { assert(input_bits==0,"Text input must not reach player movement"); F.keyboard_state_on_key(F.input_keyboard(F.App.input),cast(s32)F.Keys.W,false,F.App.time.elapsed); assert(menu_address.count>0 && menu_address[game_ui.text.caret-1]==#char "w"); UI.ui_set_text_edit(*game_ui,.{backspace=true}); menu_input_checks+=1; }
    if game_frame==5 { assert(menu_text(menu_address)==to_string(address.data)); UI.ui_set_text_edit(*game_ui,.{submit=true}); menu_input_checks+=1; }
    if game_frame==6 || game_frame==7 game_test_click("net-enet",game_frame==6);
    if game_frame==8 { assert(use_enet!=has_arg("enet")); menu_input_checks+=1; }
    if game_frame==10 || game_frame==11 game_test_click("net-host",game_frame==10);
    if game_frame==12 { assert(running); assert(!game_capture.pointer || input_bits==0); menu_input_checks+=1; }
}
