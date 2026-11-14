Voice_Talker :: struct { id:O.Network_Id; packets,empty,previous:int; last_rx,level,rate:float32; }
voice_talkers:[..]Voice_Talker;
voice_inputs,voice_outputs:[..]AUDIO.Audio_Device_Info;
mic_choice,out_choice:int=-1;
voice_show,voice_monitor,voice_talking:bool;
voice_level,voice_peak,voice_silent,voice_rate_time,voice_send_rate,voice_capture_rate:float32;
voice_captured,voice_prev_captured,voice_prev_sent:int;
voice_log:string;
voice_log_time:float32;
voice_speaking :: (id:O.Network_Id)->bool { r:=table_find_pointer(*receivers,id); return r!=null && r.*.is_speaking; }
voice_device_name :: (input:bool)->string {
    list:=ifx input then voice_inputs else voice_outputs; choice:=ifx input then mic_choice else out_choice;
    if choice<0 return "System default"; if choice>=list.count return "Device disconnected"; name:=list[choice].name;
    // The game uses the reference ASCII HUD font; Windows device names often
    // carry a translated prefix with the hardware name in parentheses.
    for c:name if c>=128 {
        first:=VOICE_STR.find_index_from_left(name,"("); last:=VOICE_STR.find_index_from_right(name,")");
        if first>=0 && last>first+1 return string.{last-first-1,name.data+first+1}; break;
    }
    return name;
}
voice_switch :: (input:bool)->bool {
    list:=ifx input then voice_inputs else voice_outputs; choice:=ifx input then mic_choice else out_choice;
    choice+=1; if choice>=list.count choice=-1; id:u32; if choice>=0 id=list[choice].id;
    candidate:AUDIO.Audio_Device;
    ok:=ifx input then AUDIO.audio_device_open_recording(*candidate,device_id=id) else AUDIO.audio_device_open(*candidate,device_id=id);
    if !ok { voice_status="Cannot open selected device; keeping the previous device."; return false; }
    if input { AUDIO.audio_device_close(*mic); mic=candidate; mic_choice=choice; voice_mic=true; voice_partial=0; }
    else { AUDIO.audio_device_close(*speaker); speaker=candidate; out_choice=choice; voice_beep(); }
    voice_status=""; return true;
}
voice_beep :: () {
    if speaker.stream==null return; samples:=NewArray(4800,float32); defer free(samples.data);
    for *v,i:samples v.*=sin(cast(float32)(i/2)*TAU*660/48000)*.12*(1-cast(float32)i/4800);
    _=F.SDL_PutAudioStreamData(speaker.stream,samples.data,cast(s32)(samples.count*4));
}
voice_rx_stat :: (id:O.Network_Id,empty:bool) {
    t:*Voice_Talker; for *it:voice_talkers if it.id==id { t=it; break; }
    if t==null { array_add(*voice_talkers,Voice_Talker.{id=id}); t=*voice_talkers[voice_talkers.count-1]; }
    t.packets+=1; if empty t.empty+=1; t.last_rx=view.time;
}
voice_controls :: (dt:float32) {
    keys:=F.input_keyboard(F.App.input);
    if voice_ready && running && !game_text_captured {
        if F.keyboard_pressed(keys,.F1) voice_show=!voice_show;
        if !mouse_look {
            if F.keyboard_pressed(keys,.M) _=voice_switch(true);
            if F.keyboard_pressed(keys,.O) _=voice_switch(false);
            if F.keyboard_pressed(keys,.L) voice_monitor=!voice_monitor;
        }
    }
    voice_rate_time+=dt; if voice_rate_time>=1 {
        voice_send_rate=cast(float32)(voice_sent-voice_prev_sent)/voice_rate_time; voice_prev_sent=voice_sent;
        voice_capture_rate=cast(float32)(voice_captured-voice_prev_captured)/voice_rate_time; voice_prev_captured=voice_captured;
        for *t:voice_talkers { t.rate=cast(float32)(t.packets-t.previous)/voice_rate_time; t.previous=t.packets; }
        voice_rate_time=0;
    }
    voice_log_time+=dt;
    if voice_log_time>=5 { voice_log_time=0;
        line:=tprint("t=% ready=% mic=% level=% capture/s=% tx/s=% received=% peak=%\n",view.time,voice_ready,voice_device_name(true),voice_level,voice_capture_rate,voice_send_rate,voice_received,voice_peak);
        next:=sprint("%%",voice_log,line); free(voice_log.data); voice_log=next;
        if voice_log.count>65536 { free(voice_log.data); voice_log=copy_string(line); }
        _=FILE.write_entire_file("build/net-fps-voice.log",voice_log);
    }
}
voice_hud :: (w,h,ui:float32) {
    if !client return; x:=26*ui; y:=h-168*ui;
    if (!voice_ready || voice_status!="") && !voice_talking text(voice_status,.{x,y+8*ui},14*ui,DIM);
    if voice_talking {
        round_rect(.{x-12*ui,y-4*ui,200*ui,34*ui},12*ui,fade(BG,.6)); text("MIC",.{x+18*ui,y+2*ui},16*ui,WHITE);
        _=G2.circle(*game_canvas,.{x+6*ui,y+13*ui},6*ui,16,mix(DANGER,WHITE,.2+.2*sin(view.time*8)));
        _=G2.rect(*game_canvas,.{x+62*ui,y+9*ui,110*ui,8*ui},fade(WHITE,.15));
        _=G2.rect(*game_canvas,.{x+62*ui,y+9*ui,110*ui*clamp(voice_level*6,cast(float32)0,cast(float32)1),8*ui},NEON);
        if voice_silent>1 text("Mic is silent: check privacy/mute, or M to switch mic",.{x,y-26*ui},15*ui,DANGER);
    }
    row:=0; for t:voice_talkers if voice_speaking(t.id) {
        obj,ok:=O.get(*client_reg,t.id); if !ok continue; p:=O.component_data(obj,Player,1); if p==null continue;
        yy:=h*.42+cast(float32)row*30*ui; round_rect(.{x-12*ui,yy-4*ui,170*ui,28*ui},10*ui,fade(BG,.55));
        for k:0..2 { bh:=(4+8*abs(sin(view.time*9+cast(float32)k*1.7)))*ui; _=G2.rect(*game_canvas,.{x+cast(float32)k*6*ui,yy+18*ui-bh,4*ui,bh},slot_color(p.slot)); }
        text(tprint("P% talking",p.slot+1),.{x+26*ui,yy},16*ui,WHITE); row+=1;
    }
    if voice_show || has_arg("voice-panel") {
        width:=min(690*ui,w-32*ui); panel:=F.Rect.{(w-width)/2,95*ui,width,(165+cast(float32)voice_talkers.count*24)*ui}; hud_panel("voice-diagnostics",panel,.{8,10,20,235},30);
        text("VOICE CHECK  /  F1",.{panel.x+18*ui,panel.y+12*ui},22*ui,NEON,0,31);
        text(ifx voice_ready then "Opus ready" else voice_status,.{panel.x+18*ui,panel.y+46*ui},15*ui,ifx voice_ready then WHITE else DANGER,0,31);
        text(tprint("MIC %  /  RMS %",voice_device_name(true),formatFloat(voice_level,trailing_width=4)),.{panel.x+18*ui,panel.y+72*ui},15*ui,WHITE,0,31);
        queued:=0; if speaker.stream!=null queued=F.SDL_GetAudioStreamQueued(speaker.stream)/384;
        text(tprint("Capture %/s  TX %/s  RX %  queued % ms  peak %",cast(int)voice_capture_rate,cast(int)voice_send_rate,voice_received,queued,formatFloat(voice_peak,trailing_width=3)),.{panel.x+18*ui,panel.y+98*ui},15*ui,DIM,0,31);
        text(ifx !voice_mic && !has_arg("voicetest") then "No microphone open" else ifx voice_talking && voice_silent>1 then "Input silent: check device/privacy" else "V talk / M input / O output test / L monitor",.{panel.x+18*ui,panel.y+124*ui},15*ui,WHITE,0,31);
        for t,i:voice_talkers { r:=table_find_pointer(*receivers,t.id); if r==null continue;
            text(tprint("#%  % pk/s  age %s  RMS %  buffer %ms  underruns %",t.id,cast(int)t.rate,formatFloat(view.time-t.last_rx,trailing_width=1),formatFloat(t.level,trailing_width=3),V.voice_receiver_buffer_ms(r.*),r.*.underruns),.{panel.x+18*ui,panel.y+(150+cast(float32)i*24)*ui},14*ui,DIM,0,31);
        }
    }
}
voice_devices :: (w,h,ui:float32) {
    panel:=F.Rect.{w/2-300*ui,h*.36+140*ui,600*ui,150*ui}; hud_panel("voice-devices",panel,.{8,10,20,230},22);
    text("MICROPHONE (M to switch)",.{panel.x+24*ui,panel.y+18*ui},14*ui,NEON,0,23);
    text(voice_device_name(true),.{panel.x+24*ui,panel.y+40*ui},18*ui,WHITE,0,23);
    text("OUTPUT (O to switch/test)   L hear your own mic",.{panel.x+24*ui,panel.y+88*ui},14*ui,NEON,0,23);
    text(voice_device_name(false),.{panel.x+24*ui,panel.y+110*ui},18*ui,WHITE,0,23);
}

VOICE_STR :: #import "String";
voice_choose_arguments :: () {
    args:=get_command_line_arguments();
    for arg,i:args {
        if (arg!="mic" && arg!="out") || i+1>=args.count continue;
        list:=ifx arg=="mic" then voice_inputs else voice_outputs;
        key:=VOICE_STR.to_lower_copy(args[i+1]); defer free(key.data);
        for device,j:list { name:=VOICE_STR.to_lower_copy(device.name); defer free(name.data); if VOICE_STR.contains(name,key) { if arg=="mic" mic_choice=j; else out_choice=j; break; } }
    }
}
