; Shared symbolic display-target handling for AFNT320 and AFNT640.
;
; The including library provides TARGET_FRONT, TARGET_BACK, ERR_ARGUMENT,
; RGMOD, target_selector, target_explicit and screen_id.

; E = BUF0/BUF1/FRONT/BACK.  Preserve the old target on an invalid selector.
afnt_set_target:
			LD	A,E
			CP	4
			JR	NC,afnt_set_target_error
			LD	(target_selector),A
			LD	A,1
			LD	(target_explicit),A
			XOR	A
			RET

afnt_set_target_error:
			LD	A,ERR_ARGUMENT
			SCF
			RET

; Resolve an explicit symbolic target once for one fnstyle/aprint call.
; With no explicit target, retain the legacy physical screen_id cache.
afnt_resolve_target:
			LD	A,(target_explicit)
			OR	A
			RET	Z
			LD	A,(target_selector)
			CP	TARGET_FRONT
			JR	Z,afnt_resolve_front
			CP	TARGET_BACK
			JR	Z,afnt_resolve_back
			LD	(screen_id),A		; BUF0/BUF1 are physical
			OR	A			; carry clear
			RET

afnt_resolve_front:
			IN	A,(RGMOD)
			AND	1
			LD	(screen_id),A
			RET

afnt_resolve_back:
			IN	A,(RGMOD)
			AND	1
			XOR	1
			LD	(screen_id),A
			RET
