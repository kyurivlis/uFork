; Self-testing ROM image

rsvd_rom:
; (    T        X        Y        Z       ADDR: VALUE )
; 0x0000 , 0x0000 , 0x0000 , 0x0000 ,  ( ^0000: #? )
; 0x0000 , 0x0000 , 0x0000 , 0x0000 ,  ( ^0001: #nil )
; 0x0000 , 0x0000 , 0x0000 , 0x0000 ,  ( ^0002: #f )
; 0x0000 , 0x0000 , 0x0000 , 0x0000 ,  ( ^0003: #t )
; 0x0000 , 0x0000 , 0x0000 , 0x0000 ,  ( ^0004: #unit )
; 0x000c , 0x0001 , 0x0001 , 0x0000 ,  ( ^0005: EMPTY_DQ )
; 0x0006 , 0x8001 , 0x0000 , 0x0000 ,  ( ^0006: #type_t )
; 0x0006 , 0x0000 , 0x0000 , 0x0000 ,  ( ^0007: #fixnum_t )
; 0x0006 , 0x8002 , 0x0000 , 0x0000 ,  ( ^0008: #actor_t )
; 0x0006 , 0x8002 , 0x0000 , 0x0000 ,  ( ^0009: PROXY_T )
; 0x0006 , 0x8002 , 0x0000 , 0x0000 ,  ( ^000a: STUB_T )
; 0x0006 , 0x8003 , 0x0000 , 0x0000 ,  ( ^000b: #instr_t )
; 0x0006 , 0x8002 , 0x0000 , 0x0000 ,  ( ^000c: #pair_t )
; 0x0006 , 0x8003 , 0x0000 , 0x0000 ,  ( ^000d: #dict_t )
; 0x0006 , 0xffff , 0x0000 , 0x0000 ,  ( ^000e: FWD_REF_T )
; 0x0006 , 0x8000 , 0x0000 , 0x0000 ,  ( ^000f: FREE_T )

boot:                       ; _ <- _
    pair 0                  ; state=()
    push reboot             ; state beh=reboot
    beh -1                  ; --
    ref test_actors

reboot:                     ; _ <- _
    dup 0                   ; --
    part 0                  ; --
    ref commit

test_pairs:
    pair 0                  ; ()
    assert #nil             ; --
    push 3                  ; 3
    push 2                  ; 3 2
    pair 1                  ; (2 . 3)
    push 1                  ; (2 . 3) 1
    pair 1                  ; (1 2 . 3)
    part 1                  ; (2 . 3) 1
    assert 1                ; (2 . 3)
    dup 0                   ; (2 . 3)
    part 1                  ; 3 2
    assert 2                ; 3
    dup 1                   ; 3 3
    part 1                  ; 3 #? #?
    drop 1                  ; 3 #?
    assert #?               ; 3
    drop 0                  ; 3
    assert 3                ; --
    ref test_if

test_if:
    part 1                  ; #? #?
    drop 1                  ; #?
    if stop                 ; --
    push 0                  ; 0
    eq 0                    ; #t
    if_not stop             ; --
    push -1                 ; -1
    eq 0                    ; #f
    if stop                 ; --
    push #nil               ; ()
    if stop                 ; --
    push #unit              ; #unit
    if_not stop             ; --
    push 0                  ; 0
    if stop                 ; --
    ref test_nth

test_nth:
    push list-0             ; (273 546 819)
    part 1                  ; (546 819) 273
    assert 273              ; (546 819)
    part 1                  ; (819) 546
    assert 546              ; (819)
    part 1                  ; () 819
    assert 819              ; ()
    assert #nil             ; --
    push list-0             ; (273 546 819)
    nth 0                   ; (273 546 819)
    assert list-0           ; --
    push list-0             ; (273 546 819)
    nth 1                   ; 273
    assert 273              ; --
    push list-0             ; (273 546 819)
    nth -1                  ; (546 819)
    assert list-1           ; --
    push list-0             ; (273 546 819)
    nth 2                   ; 546
    assert 546              ; --
    push list-0             ; (273 546 819)
    nth -2                  ; (819)
    assert list-2           ; --
    push list-0             ; (273 546 819)
    nth 3                   ; 819
    assert 819              ; --
    push list-0             ; (273 546 819)
    nth -3                  ; ()
    assert list-3           ; --
;    assert #nil             ; --
    push list-0             ; (273 546 819)
    nth 4                   ; #?
    assert #?               ; --
    push list-0             ; (273 546 819)
    nth -4                  ; #?
    assert #?               ; --
    ref test_actors

test_actors:
    ref commit

; static data
list-0:                     ; (273 546 819)
    pair_t 16#111           ; 273
list-1:                     ; (546 819)
    pair_t 16#222           ; 546
list-2:                     ; (819)
    pair_t 16#333           ; 819
list-3:                     ; ()
    ref #nil

; adaptated from `lib.asm`
once_beh:                   ; (rcvr) <- msg
    push #nil               ; state=()
    push sink_beh           ; state beh=sink_beh
    beh -1                  ; --
    ; ref fwd_beh
fwd_beh:                    ; (rcvr) <- msg
    msg 0                   ; msg
    state 1                 ; msg rcvr
    ref send_msg

; shared tails from `std.asm`
cust_send:                  ; msg
    msg 1                   ; msg cust
send_msg:                   ; msg cust
    send -1                 ; --
sink_beh:                   ; _ <- _
commit:
    end commit
stop:
    end stop

.export
    boot
