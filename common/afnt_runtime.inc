; Shared window-safety and interrupt-state helpers for AFNT DLLs.
;
; The including library provides video_window, code_window, restore_ei,
; ERR_WINDOW and YPORT.

; A = window containing the current stack pointer (0..3).
afnt_current_stack_window:
			LD	HL,0
			ADD	HL,SP
			LD	A,H
			AND	0xC0
			RLCA
			RLCA
			RET

; Reject a VRAM window that would hide either executing code or the stack.
afnt_ensure_window_safe:
			LD	A,(video_window)
			LD	B,A
			LD	A,(code_window)
			CP	B
			JR	Z,afnt_window_conflict
			CALL	afnt_current_stack_window
			CP	B
			JR	Z,afnt_window_conflict
			XOR	A
			RET

afnt_window_conflict:
			LD	A,ERR_WINDOW
			SCF
			RET

; Enter an interrupt-disabled accelerator section while remembering IFF2.
afnt_enter_di:
			LD	A,I
			DI
			JP	PO,afnt_enter_di_off
			LD	A,1
			LD	(restore_ei),A
			RET
afnt_enter_di_off:
			XOR	A
			LD	(restore_ei),A
			RET

; PORT_Y must already be restored before leaving the critical section.
afnt_leave_di:
			LD	A,(restore_ei)
			OR	A
			RET	Z
			EI
			RET
