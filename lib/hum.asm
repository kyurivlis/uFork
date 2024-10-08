; Runtime support for compiled Humus.

.import
    dev: "https://ufork.org/lib/dev.asm"
    std: "https://ufork.org/lib/std.asm"

push_op:
    ref 2
msg_op:
    ref 24

; A Humus closure is represented as an assembly procedure taking one argument
; and returning one value. A closure is created by prefixing some precompiled
; code with an instruction pushing the environment onto the stack.

make_closure:               ; ( code env k -- closure )
    roll -3                 ; k code env
    push push_op            ; k code env push_op
    push #instr_t           ; k code env push_op #instr_t
    quad 4                  ; k closure=[#instr_t, push_op, env, code]
    ref std.return_value

; Closure code expects a stack like

;                           ; args k env

; where 'args' is the single argument, 'k' is the continuation to return to,
; and 'env' is the closure's environment.

; Immediately, the arguments are incorporated into the environment.

;   roll 3                  ; k env args
;   pair 1                  ; k env'=(args . env)

; After evaluating the return value, the code returns (or continues) to 'k'.

return:                     ; k env' rv
    roll -3                 ; rv k env'
    drop 1                  ; rv k
    return                  ; rv

; Tail calls are achieved by modifying the existing frame before jumping
; directly to the procedure or compiled closure code.

tail_call:                  ; k env procedure args
    roll -4                 ; args k env procedure
    roll 2                  ; args k procedure env
    drop 1                  ; args k procedure
    jump                    ; args k
self_tail_call:             ; k env env' code args
    roll -5                 ; args k env env' code
    roll 3                  ; args k env' code env
    drop 1                  ; args k env' code
    jump                    ; args k env'

; A block is essentially a closure that take no arguments. Because blocks have a
; different signature, and are executed implicitly, they must be
; distinguishable from closures. A custom type is defined for this purpose.

block_t:                    ; [block_t, code, env]
    type_t 2

make_block:                 ; ( env code k -- block )
    roll -3                 ; k env code
    push block_t            ; k env code block_t
    quad 3                  ; k block=[block_t, code, env]
    ref std.return_value

execute_block:              ; ( value k -- )
    roll -2                 ; k value
    quad -3                 ; k Y X T
    eq block_t              ; k Y X block_t?(T)
    if execute_k            ; k env=Y code=X
    drop 2                  ; k
execute_k:
    jump

; At compile time, it is not always possible to discern the intended role of a
; closure. Will it be used as the behavior for an actor, or called as a
; procedure?

; Consequently, the compiled code for a closure needs enough flexibility to
; either handle a message or to be called as a procedure. Clearly closures can
; be called as procedures, because they conform to the calling convention of
; assembly procedures.

; Before a closure can be invoked as a behavior for an actor, the 'args' and 'k'
; values must be provided on the stack. This is accomplished by 'beh', the
; generic actor behavior.

; It first pushes the message onto the stack as 'args', then pushes a
; continuation as 'k'. Finally it retrieves the closure from the actor's state
; and calls it. If the returned value is a block, it is executed for its
; effects. Otherwise the transaction is aborted.

; Use 'beh' with 'beh -1' or 'new -1', for example:

;   push closure            ; closure
;   push hum.beh            ; closure beh
;   beh -1                  ; actor=beh.closure

beh:                        ; closure <- msg
    push std.commit         ; commit
    msg 0                   ; commit args=msg
    push beh_end            ; commit args k=beh_end
    state 0                 ; commit args k closure
    jump
beh_end:                    ; commit rv
    quad -3                 ; commit Y X T
    eq block_t              ; commit Y X T==block_t
    if_not std.abort        ; k=commit env=Y code=X
    jump

; Symbols are interned as quads containing a pair list of code points encoding
; the symbol text.

symbol_t:                   ; [symbol_t, string]
    type_t 1

; Construct the top level environment from capabilities in the boot message.

random_fwd_beh:             ; random_dev <- (cust . n)
    msg -1                  ; n
    push 1                  ; n 1
    alu sub                 ; limit=n-1
    msg 1                   ; limit cust
    state 0                 ; limit cust random_dev
    send 2                  ; --
    ref std.commit

timer_fwd_beh:              ; timer_dev <- (dt msg . actor)
    msg 2                   ; message=msg
    msg -2                  ; message target=actor
    msg 1                   ; message target delay=dt
    state 0                 ; message target delay timer_dev
    send 3                  ; --
    ref std.commit

prepare_env:                ; ( k -- env )
    push #?                 ; k #?
    msg 0                   ; k #? {caps}
    push dev.debug_key      ; k #? {caps} debug_key
    dict get                ; k #? println=debug_dev
    msg 0                   ; k #? println {caps}
    push dev.timer_key      ; k #? println {caps} timer_key
    dict get                ; k #? println timer_dev
    push timer_fwd_beh      ; k #? println timer_dev timer_fwd_beh
    new -1                  ; k #? println timer=timer_fwd_beh.timer_dev
    msg 0                   ; k #? println timer {caps}
    push dev.random_key     ; k #? println timer {caps} random_key
    dict get                ; k #? println timer random_dev
    push random_fwd_beh     ; k #? println timer random_dev random_fwd_beh
    new -1                  ; k #? println timer random=random_fwd_beh.random_dev
    pair 2                  ; k #? scope=(random timer . println)
    pair 1                  ; k env=(scope . #?)
    ref std.return_value

; Lastly we provide some miscellaneous procedures.

drop_return_f:              ; k value
    drop 1                  ; k
    ref std.return_f

drop_return_t:              ; k value
    drop 1                  ; k
    ref std.return_t

is_bool:                    ; value k
    roll -2                 ; k value
    dup 1                   ; k value value
    eq #t                   ; k value value==#t
    if drop_return_t        ; k value
    eq #f                   ; k value==#f
    if std.return_t         ; k
    ref std.return_f

is_bool_pair:               ; value k
    roll -2                 ; k value=(head . tail)
    part 1                  ; k tail head
    call is_bool            ; k tail bool?(head)
    if_not drop_return_f    ; k tail
    call is_bool            ; k bool?(tail)
    if_not std.return_f     ; k
    ref std.return_t

compare:                    ; args k
    roll -2                 ; k args
    part 1                  ; k b a
    dup 2                   ; k b a b a
    cmp eq                  ; k b a b==a
    if compare_eq           ; k b a
    dup 2                   ; k b a b a
    cmp lt                  ; k b a b<a
    if compare_gt           ; k b a
    cmp gt                  ; k b>a
    if compare_lt           ; k
    ref std.return_undef
compare_lt:                 ; k
    push -1                 ; k -1
    ref std.return_value
compare_eq:                 ; k b a
    drop 2                  ; k
    ref std.return_zero
compare_gt:                 ; k b a
    drop 2                  ; k
    ref std.return_one

boot:                       ; () <- {caps}
    msg 0                   ; {caps}
    push dev.debug_key      ; {caps} debug_key
    dict get                ; debug_dev
    push 123                ; debug_dev b
    push 123                ; debug_dev b a
    pair 1                  ; debug_dev (a . b)
    call compare            ; debug_dev cmp
    pick 2                  ; cmp debug_dev
    send -1                 ; --
    ref std.commit

.export
    beh
    block_t
    boot
    compare
    execute_block
    is_bool
    is_bool_pair
    make_block
    make_closure
    prepare_env
    return
    self_tail_call
    symbol_t
    tail_call
