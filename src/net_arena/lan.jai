// Windows IPv4 adapter enumeration for the reference host-menu address hints.
// Structures follow the Windows SDK iptypes.h (GetAdaptersInfo).
Lan_Address :: struct { text:string; score:int; }
lan_addresses:[..]Lan_Address;
lan_dispose :: () { for a:lan_addresses free(a.text.data); array_free(lan_addresses); }
lan_init :: () {
    #if OS == .WINDOWS {
        size:u32; result:=GetAdaptersInfo(null,*size); if result!=111 || size==0 return;
        memory:=alloc(size); defer free(memory); first:=cast(*Adapter_Info)memory;
        if GetAdaptersInfo(first,*size)!=0 return;
        adapter:=first;
        while adapter!=null {
            description:=to_string(adapter.description.data); virtual:=false;
            for tag:string.["vEthernet","VMware","VirtualBox","WSL","Hyper-V","Loopback"] if GSTR.contains(description,tag) virtual=true;
            lease:=*adapter.ip; gateway:=to_string(adapter.gateway.ip.data);
            while lease!=null {
                ip:=to_string(lease.ip.data); score:=lan_score(ip,gateway!="" && gateway!="0.0.0.0",virtual);
                if score>=0 {
                    duplicate:=false; for a:lan_addresses if a.text==ip duplicate=true;
                    if !duplicate array_add(*lan_addresses,Lan_Address.{copy_string(ip),score});
                }
                lease=lease.next;
            }
            adapter=adapter.next;
        }
        // Stable descending order, matching the reference's preference for real LAN adapters.
        for i:1..lan_addresses.count-1 { j:=i; while j>0 && lan_addresses[j].score>lan_addresses[j-1].score { temp:=lan_addresses[j]; lan_addresses[j]=lan_addresses[j-1]; lan_addresses[j-1]=temp; j-=1; } }
    }
}
lan_score :: (ip:string,gateway,virtual:bool)->int {
    parts:[4]int; index:=0;
    for c:ip { if c==46 { index+=1; if index>3 return -1; } else if c>=48 && c<=57 parts[index]=parts[index]*10+cast(int)c-48; else return -1; }
    if index!=3 || parts[0]==0 || parts[0]==127 || (parts[0]==169 && parts[1]==254) || (parts[0]==198 && (parts[1]&0xfe)==18) return -1;
    score:=0;
    if parts[0]==10 || (parts[0]==172 && (parts[1]&0xf0)==16) || (parts[0]==192 && parts[1]==168) score+=2;
    if parts[0]==100 && (parts[1]&0xc0)==64 score+=1;
    if gateway score+=4; if virtual score-=4; return score;
}
#scope_file
#if OS == .WINDOWS {
    iphelper :: #library,system "iphlpapi";
    IP_String :: struct { next:*IP_String; ip,mask:[16]u8; context_:u32; }
    Adapter_Info :: struct {
        next:*Adapter_Info; combo:u32; name:[260]u8; description:[132]u8;
        address_length:u32; address:[8]u8; index_,type_,dhcp:u32; current_ip:*IP_String;
        ip,gateway,dhcp_server:IP_String; have_wins:s32; primary_wins,secondary_wins:IP_String;
        lease_obtained,lease_expires:s64;
    }
    GetAdaptersInfo :: (info:*Adapter_Info,size:*u32)->u32 #foreign iphelper;
}
