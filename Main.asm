; -----------------
; | Digital Clock |
; -----------------

; Initializer - Constants and Variables
DataSeg						equ		0100h
StackPtrStart				equ		0800h
Port1A						equ		0800h
Port1B						equ		0801h
Port1C						equ		0802h
Port1Cntrl					equ		0803h
Port2A						equ		0804h
Port2B						equ		0805h
Port2C						equ		0806h
Port2Cntrl					equ		0807h
Cntr0						equ		0808h
Cntr1						equ		0809h
Cntr2						equ		080Ah
CntrCntrl					equ		080Bh
TotalDataSize				equ		100
Cntr0Start					equ		19886
Cntr1Start					equ		1193
Cntr2Start					equ		100


; Clock Time Manager - Constants and Variables
ClkTimeErrPulses			equ		59658
ClkTime_MsUpdated			equ		1b
ClkTime_SecUpdated			equ		10b
ClkTime_MinUpdated			equ		100b
ClkTimeHr					DB		?
ClkTimeMin					DB		?
ClkTimeSec					DB		?
ClkTimeMs					DB		?
ClkTimeCntrVal				DW		?
ClkTimeErr					DW		?


; Input Manager - Constants and Variables


; Parallel Routine Caller - Constants and Variables
ParRtnCllrFlags				DB		?
ParRtnCllr_DoMsCall			equ		1


; Display Routine - Constants and Variables
DispRtnOnTime				equ		15
DispRtnTotalTime			equ		30
DispRtnHr					DB		?
DispRtnMin					DB		?
DispRtnSec					DB		?
DispRtnHmsFlags				DB		?
DispRtn_SecOn				equ		0
DispRtn_SecBlink			equ		1
DispRtn_MinOn				equ		2
DispRtn_MinBlink			equ		3
DispRtn_HrOn				equ		4
DispRtn_HrBlink				equ		5
DispRtn_ClnOn				equ		6
DispRtn_ClnBlink			equ		7
DispRtnSymFlags				DB		?
DispRtn_SwOn				equ		0
DispRtn_SwBlink				equ		1
DispRtn_AlrmOn				equ		2
DispRtn_AlrmBlink			equ		3
DispRtn_VibrOn				equ		4
DispRtn_VibrBlink			equ		5
DispRtn_BellOn				equ		6
DispRtn_BellBlink			equ		7
DispRtnCntr					DB		?


; Response Routine - Constants and Variables


; Backlight Routine - Constants and Variables


; Low Battery Routine - Constants and Variables
LowBattRtnFlags				DB		?
LowBattRtn_Low				equ		1


; Time Set Routine - Constants and Variables




; Initializer
; -----------
initializer:
; initialize software environment
mov		ax, DataSeg
mov		ds, ax
mov		es, ax
mov		ss, ax
mov		sp, StackPtrStart
; initialize memory
mov		di, 0
mov		cx, TotalDataSize
cld
init_mem_loop:
stosb
dec		cx
jnz		init_mem_loop
; initialize I/O devices
mov		BYTE PTR [Port1Cntrl], 10000000b
mov		BYTE PTR [Port2Cntrl], 10000010b
mov		BYTE PTR [CntrCntrl], 00110100b
mov		ax, Cntr0Start
mov		ClkTimeCntrVal, ax
mov		[Cntr0], al
mov		[Cntr0], ah
mov		BYTE PTR [CntrCntrl], 01110110b
mov		ax, Cntr1Start
mov		[Cntr1], al
mov		[Cntr1], ah
mov		BYTE PTR [CntrCntrl], 10110110b
mov		ax, Cntr2Start
mov		[Cntr2], al
mov		[Cntr2], ah


; Clock Time Manager
; ------------------
clock_time_manager:
; Check for (1/60)s completion
mov		bx, 0
mov		BYTE PTR [CntrControl], 00000100b
mov		al, [Cntr0]
mov		ah, [Cntr1]
cmp		ax, ClkTimeCntrVal
mov		ClkTimeCntrVal, ax
jbe		clk_time_ud
; Update Time - Accomodate Time Error, if required
inc		ClkTimeErr
cmp		ClkTimeErr, ClkTimeErrPulses
jb		clk_time_err_n
sub		ClkTimeErr, ClkTimeErrPulses
jmp		clk_time_ud
; No Time Error, Update Clock Time
clk_time_err_n:
or		bx, ClkTime_MsUpdated
inc		ClkTimeMs
cmp		ClkTimeMs, 60
jb		clk_time_ud
sub		ClkTimeMs, 60
or		bx, ClkTime_SecUpdated
inc		ClkTimeSec
cmp		clkTimeSec, 60
jb		clk_time_ud
sub		ClkTimeSec, 60
or		bx, ClkTime_MinUpdated
inc		ClkTimeMin
cmp		ClkTimeMin, 60
jb		clk_time_ud
sub		ClkTimeMin, 60
inc		ClkTimeHr
cmp		ClkTimeHr, 24
jb		clk_time_ud
sub		ClkTimeHr, 24
clk_time_ud:
test	bx, ClkTime_MsUpdated
jz		clk_time_udt_n
call	par_rtn_cllr_Ms
test	bx, ClkTime_SecUpdated
jz		clk_time_udt_n
call	par_rtn_cllr_Sec
test	bx, ClkTime_MinUpdated
jz		clk_time_udt_n
call	par_rtn_cllr_Min
clk_time_udt_n:


; Input Manager
; -------------
input_manager:
mov		al, [Port2B]
test	al, 1111b
jz		input_n
; Update the inputs
test	al, 1b
jz		input_t_down

input_t_down:

input_n:
jmp		clock_time_manager


; Parallel Routine Caller
; -----------------------
par_rtn_cllr_Ms:
xor		ParRtnCllrFlags, ParRtnCllr_DoMsCall
test	ParRtnCllrFlags, 1
jz		par_rtn_cllr_Ms_n
call	mode_mngt_rtn
call	display_rtn
call	response_rtn
par_rtn_cllr_Ms_n:
ret
par_rtn_cllr_Sec:
call	backlight_rtn
ret
par_rtn_cllr_Min:
call	low_batt_rtn
ret


; Display Routine
; ---------------
inc		DispRtnCntr
cmp		DispRtnCntr, DispRtnTotalTime
jb		disp_rtn_cntr_n
sub		DispRtnCntr, DispRtnTotalTime
disp_rtn_cntr_n:
mov		bl, DispRtnHsmFlags
mov		bh, DispRtnSymFlags
test	LowBattRtn, LowBattRtn_Low
jnz		disp_rtn_blink_on
cmp		DispRtnCntr, DispRtnOnTime
ja		disp_rtn_blink_off
disp_rtn_blink_on:
mov		al, bl
mov		cl, DispRtn_SecOn
shr		al, cl
neg		al
xor		al, al
add		al, DispRtnSec
daa
mov		[Port1C], al
disp_rtn_blink_on_min:
test	bl, DispRtn_MinOn
jz		disp_rtn_blink_on_hr
xor		al, al
add		al, DispRtnMin
daa
mov		[Port1B], al
disp_rtn_blink_on_hr:
test	bl, DispRtn_HrOn
jz		disp_rtn_blink_on_cln
xor		al, al
add		al, DispRtnHr
daa
mov		[Port1A], DispRtnHr
disp_rtn_blink_on_cln:
test	bl, DispRtn_ClnOn
jz		disp_rtn_blink_on_sw


disp_rtn_blink_off:
