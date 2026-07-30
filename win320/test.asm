        org #8100-512

; Stage-0 diagnostic. WIN320.DLL must be beside this EXE.
        dw #5845
        db #45,#00
        dw #0200,#0000,#0000,#0000,#0000,#0000
        dw start,start,#bff0
        ds 490

        include "win320.inc"

        define LIBMAN_MAX_LIBS 1
        define LIBMAN_NO_LEGACY_API
        define LIBMAN_DIAGNOSTICS

start:
        ld hl,msg_banner
        call puts
        ld hl,dll_name
        ld a,3
        call LIBMAN.l_load
        jp c,load_failed
        ld (dll_handle),hl
        ld a,1
        ld (dll_loaded),a

        ld hl,(dll_handle)
        ld b,WIN_GET_VERSION
        call LIBMAN.l_call
        jp c,call_failed
        or a
        jp nz,status_failed
        ld a,d
        ld (abi_major),a
        ld a,e
        ld (abi_minor),a
        ld (abi_caps),ix

        ld hl,(dll_handle)
        ld de,config
        ld b,WIN_GET_CONFIG
        call LIBMAN.l_call
        jp c,call_failed
        or a
        jp nz,status_failed

        ld hl,(dll_handle)
        ld b,WIN_LOAD_FONT
        call LIBMAN.l_call
        jp c,call_failed
        cp WIN_ERR_UNSUPPORTED
        jp nz,status_failed

        call free_library
        ld hl,msg_ok
        call puts
        ld a,(abi_major)
        call print_hex8
        ld a,'.'
        call putc
        ld a,(abi_minor)
        call print_hex8
        ld hl,msg_caps
        call puts
        ld hl,(abi_caps)
        call print_hex16
        ld hl,msg_config
        call puts
        ld a,(config+WIN_CFG_CODE_WINDOW)
        call print_hex8
        ld hl,msg_font
        call puts
        ld a,(config+WIN_CFG_FONT_PAGE)
        call print_hex8
        ld hl,msg_work
        call puts
        ld a,(config+WIN_CFG_DATA_WINDOW)
        call print_hex8
        ld a,'/'
        call putc
        ld a,(config+WIN_CFG_VRAM_WINDOW)
        call print_hex8
        ld hl,msg_newline
        call puts
        jr wait_exit

load_failed:
        ld hl,msg_load_failed
        call puts
        ld a,(LIBMAN.l_reason)
        call print_hex8
        ld hl,msg_dss
        call puts
        ld a,(LIBMAN.l_dss_error)
        call print_hex8
        ld hl,msg_init
        call puts
        ld a,(LIBMAN.l_init_status)
        call print_hex8
        ld hl,msg_newline
        call puts
        jr wait_exit

call_failed:
        ld a,#ff
status_failed:
        ld (api_status),a
        call free_library
        ld hl,msg_api_failed
        call puts
        ld a,(api_status)
        call print_hex8
        ld hl,msg_newline
        call puts

wait_exit:
        ld hl,msg_prompt
        call puts
        ld c,#30
        rst #10
        ld bc,#0041
        rst #10
        ret

free_library:
        ld a,(dll_loaded)
        or a
        ret z
        xor a
        ld (dll_loaded),a
        ld hl,(dll_handle)
        call LIBMAN.l_free
        ret

puts:
        ld c,#5c
        rst #10
        ret

putc:
        ld (char_buffer),a
        ld hl,char_buffer
        ld c,#5c
        rst #10
        ret

print_hex16:
        push hl
        ld a,h
        call print_hex8
        pop hl
        ld a,l
print_hex8:
        push af
        rrca
        rrca
        rrca
        rrca
        call hex_nibble
        call putc
        pop af
        call hex_nibble
        jp putc

hex_nibble:
        and #0f
        add a,'0'
        cp '9'+1
        ret c
        add a,'A'-'9'-1
        ret

dll_name:       db "WIN320.DLL",0
msg_banner:     db "WIN320 stage 0 diagnostic: loading DLL...",13,10,0
msg_ok:         db "PASS  ABI=",0
msg_caps:       db " caps=",0
msg_config:     db " codewin=",0
msg_font:       db " fontpage=",0
msg_work:       db " work(data/vram)=",0
msg_load_failed: db "FAIL  libman reason=$",0
msg_dss:        db " DSS=$",0
msg_init:       db " init=$",0
msg_api_failed: db "FAIL  API status=$",0
msg_prompt:     db "Press any key.",13,10,0
msg_newline:    db 13,10,0
char_buffer:    db 0,0

dll_handle:     dw 0
dll_loaded:     db 0
api_status:     db 0
abi_major:      db 0
abi_minor:      db 0
abi_caps:       dw 0
config:         db WIN_CONFIG_SIZE
                ds WIN_CONFIG_SIZE-1,0

        include "libman.asm"
