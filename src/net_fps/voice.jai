V :: #import "thirdparty/voice";
AUDIO :: #import "kit/audio";
opus:V.Opus_Library; rnnoise:V.Rnnoise_Library; voice_config:V.Config;
sender:V.Voice_Sender; mic,speaker:AUDIO.Audio_Device;
receivers:Table(O.Network_Id,*V.Voice_Receiver);
voice_ready,voice_audio,voice_mic,voice_rn:bool;
voice_status:string="Voice not initialized";
voice_pcm,voice_mix,voice_mono:[]float32;
voice_partial,voice_tail,voice_sent,voice_received:int; voice_clock,voice_phase,voice_max_peak:float32;
voice_init :: () {
    voice_audio=AUDIO.audio_init();
    if voice_audio { voice_inputs=AUDIO.audio_device_list(true); voice_outputs=AUDIO.audio_device_list(false); }
    voice_config=V.config_default(); assert(V.config_init(*voice_config));
    if !V.opus_load(*opus) { voice_status="Voice unavailable: install opus.dll (V: push-to-talk)"; print("%\n",voice_status); return; }
    voice_rn=V.rnnoise_load(*rnnoise);
    if !voice_audio { voice_status="Voice unavailable: audio initialization failed"; return; }
    voice_choose_arguments();
    output_id:u32; if out_choice>=0 output_id=voice_outputs[out_choice].id;
    input_id:u32; if mic_choice>=0 input_id=voice_inputs[mic_choice].id;
    if !AUDIO.audio_device_open(*speaker,device_id=output_id) { voice_status="Voice unavailable: no output device"; return; }
    if !game_shot && !game_smoke && !has_arg("server") && !has_arg("voicetest") voice_mic=AUDIO.audio_device_open_recording(*mic,device_id=input_id);
    voice_ready=V.voice_sender_init(*sender,*voice_config,*opus,ifx voice_rn then *rnnoise else null,V.OPUS_MAX_PACKET_BYTES,voice_relay,null);
    voice_pcm=NewArray(voice_config.samples_per_frame,float32); voice_mono=NewArray(2880,float32); voice_mix=NewArray(5760,float32);
    voice_status=ifx has_arg("voicetest") then "Synthetic Opus loopback" else ifx voice_mic then "V: push-to-talk  /  spatial Opus voice" else "Voice: listening only (no microphone)";
}
voice_relay :: (index:int,timestamp:float64,data:[]u8,user:*void) {
    if !running || !client return; obj,ok:=O.find_owned(*client_reg,sess.client_server_id); if !ok return;
    w:C.Writer; C.writer_init(*w); defer C.writer_destroy(*w);
    C.write_uint32(*w,cast,trunc(u32)index,.Uncompressed); C.write_raw_double(*w,timestamp); C.write_u8_array_with_count(*w,data,.Loose);
    bytes:=C.writer_to_array(*w); defer free(bytes.data); if RPC.send(*runtime.client.rpc,4,obj.id,.Observers,bytes,channel=.Unreliable,include_sender=has_arg("voicetest")) voice_sent+=1;
}
on_voice :: (ctx:*RPC.Context,data:[]u8) {
    if ctx.manager.authority || !voice_ready return;
    if ctx.object.owner==sess.client_server_id && !has_arg("voicetest") return;
    r:=RPC.reader(data); index:=C.read_uint32(*r,.Uncompressed); timestamp:=C.read_raw_double(*r,0); packet:=C.read_u8_array_with_count(*r,.Loose); defer free(packet.data);
    if r.err!=.None || packet.count>V.OPUS_MAX_PACKET_BYTES return;
    receiver:=table_find_pointer(*receivers,ctx.object.id);
    if receiver==null { fresh:=New(V.Voice_Receiver); if !V.voice_receiver_init(fresh,*voice_config,*opus) { free(fresh); return; } table_add(*receivers,ctx.object.id,fresh); receiver=table_find_pointer(*receivers,ctx.object.id); }
    V.voice_receiver_receive(receiver.*,cast(int)index,timestamp,packet); voice_received+=1; voice_rx_stat(ctx.object.id,packet.count==0);
}
voice_capture_frame :: (talking:bool) {
    period:=cast(float32)voice_config.samples_per_frame/cast(float32)voice_config.sample_rate;
    voice_level=0; for v:voice_pcm voice_level+=v*v; voice_level=sqrt(voice_level/cast(float32)voice_pcm.count); voice_captured+=1;
    if talking && voice_level<.0001 voice_silent+=period; else voice_silent=0;
    if talking { _=V.voice_sender_send(*sender,voice_pcm); voice_tail=3; }
    else if voice_tail>0 { _=V.voice_sender_send(*sender,.[]); voice_tail-=1; }
    if voice_monitor && receivers.count==0 {
        for v,i:voice_pcm { voice_mix[i*2]=v; voice_mix[i*2+1]=v; }
        _=F.SDL_PutAudioStreamData(speaker.stream,voice_mix.data,cast(s32)(voice_pcm.count*8));
    }
}
voice_update :: (dt:float32) {
    if !voice_ready || !running || !client return;
    talking:=(F.keyboard_down(F.input_keyboard(F.App.input),.V) || has_arg("openmic") || has_arg("voicetest")) && local_player()!=null && (voice_mic || has_arg("voicetest")); voice_talking=talking;
    if has_arg("voicetest") {
        voice_clock+=dt; period:=cast(float32)voice_config.samples_per_frame/cast(float32)voice_config.sample_rate;
        while voice_clock>=period { voice_clock-=period; for *v:voice_pcm { v.*=sin(voice_phase)*.1; voice_phase+=TAU*440/cast(float32)voice_config.sample_rate; if voice_phase>TAU voice_phase-=TAU; } voice_capture_frame(talking); }
    } else if voice_mic {
        if AUDIO.audio_device_available_samples(*mic)>voice_pcm.count*8 { F.SDL_ClearAudioStream(mic.stream); voice_partial=0; }
        // SDL capture chunks need not match an Opus frame. Keep the partial tail.
        while true {
            got:=AUDIO.audio_device_read(*mic,array_view(voice_pcm,voice_partial,voice_pcm.count-voice_partial));
            if got<=0 break; voice_partial+=got;
            if voice_partial==voice_pcm.count { voice_capture_frame(talking); voice_partial=0; }
        }
    }
    if !talking voice_level*=.8;
    gone:[..]O.Network_Id; defer array_free(gone);
    for receiver,id:receivers { obj,ok:=O.get(*client_reg,id); if !ok array_add(*gone,id); }
    for id:gone { r:=table_find_pointer(*receivers,id); V.voice_receiver_dispose(r.*); free(r.*); table_remove(*receivers,id); for i:0..voice_talkers.count-1 if voice_talkers[i].id==id { array_unordered_remove_by_index(*voice_talkers,i); break; } }
    voice_playback();
}
voice_playback :: () {
    if receivers.count==0 return;
    queued:=F.SDL_GetAudioStreamQueued(speaker.stream)/8;
    if queued>5760 { F.SDL_ClearAudioStream(speaker.stream); queued=0; }
    need:=2880-queued; if need<=0 return;
    mono:=array_view(voice_mono,0,need); mixed:=array_view(voice_mix,0,need*2); for *v:mixed v.*=0;
    listener:=local_player();
    for receiver,id:receivers {
        _=V.voice_receiver_pull(receiver,mono); gain:float32=1; pan:float32;
        obj,ok:=O.get(*client_reg,id); if ok && listener!=null { p:=O.component_data(obj,Player,1); if p!=null {
            d:=p.pos-listener.pos; dist:=sqrt(W.v3_dot(d,d)); gain=clamp(1.25-dist/35,cast(float32).3,cast(float32)1);
            flat:=sqrt(d.x*d.x+d.z*d.z); if flat>.01 pan=clamp((d.x*cos(yaw)-d.z*sin(yaw))/flat,cast(float32)-1,cast(float32)1)*.8;
        } }
        rms:float32; for v:mono rms+=v*v; rms=sqrt(rms/cast(float32)need);
        for *t:voice_talkers if t.id==id t.level=max(rms,t.level*.9);
        theta:=(pan+1)*PI/4; gl:=gain*cos(theta)*1.4; gr:=gain*sin(theta)*1.4;
        for v,i:mono { mixed[i*2]+=v*gl; mixed[i*2+1]+=v*gr; }
    }
    voice_peak=0; for v:mixed voice_peak=max(voice_peak,abs(v)); voice_max_peak=max(voice_max_peak,voice_peak);
    AUDIO.apply_volume(mixed,mixed,1);
    _=F.SDL_PutAudioStreamData(speaker.stream,mixed.data,cast(s32)(mixed.count*4));
}
voice_reset :: () { for receiver:receivers { V.voice_receiver_dispose(receiver); free(receiver); } table_reset_keeping_memory(*receivers); voice_tail=0; voice_clock=0; voice_partial=0; voice_talkers.count=0; voice_talking=false; voice_level=0; voice_silent=0; }
voice_stop :: () {
    voice_reset(); AUDIO.audio_device_list_free(*voice_inputs); AUDIO.audio_device_list_free(*voice_outputs); array_free(voice_talkers); free(voice_log.data); deinit(*receivers); if voice_ready V.voice_sender_dispose(*sender);
    AUDIO.audio_device_close(*mic); AUDIO.audio_device_close(*speaker); free(voice_pcm.data); free(voice_mix.data); free(voice_mono.data);
    V.rnnoise_dispose(*rnnoise); V.opus_dispose(*opus); if voice_audio AUDIO.audio_shutdown();
}
