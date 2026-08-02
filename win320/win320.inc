; WIN320.DLL public ABI 1.0 constants for sjasmplus clients.
WIN_INIT                 equ 0
WIN_FREE                 equ 1
WIN_SET_WORK_WINDOWS     equ 2
WIN_SET_SCREEN           equ 3
WIN_GET_VERSION          equ 4
WIN_GET_CONFIG           equ 5
WIN_LOAD_FONT            equ 6
WIN_SET_THEME            equ 7
WIN_SET_TEXT_FORMAT      equ 8
WIN_SET_ORIGIN           equ 9
WIN_STYLE                equ 10
WIN_FILL_RECT            equ 11
WIN_FRAME                equ 12
WIN_PANEL                equ 13
WIN_SEPARATOR            equ 14
WIN_INVERT_RECT          equ 15
WIN_FOCUS_RECT           equ 16
WIN_LABEL                equ 17
WIN_BUTTON               equ 18
WIN_DRAW                 equ 19
WIN_DRAW_ITEM            equ 20
WIN_UPDATE               equ 21
WIN_SET_BACKSTORE        equ 22
WIN_OPEN                 equ 23
WIN_CLOSE                equ 24
WIN_POLL                 equ 25
WIN_TRACK                equ 26
WIN_WAIT_RELEASE         equ 27
WIN_SET_CURSOR           equ 28
WIN_EDIT_DRAW            equ 29
WIN_EDIT                 equ 30
WIN_ICON                 equ 31
WIN_PROGRESS_INIT        equ 32
WIN_PROGRESS_DRAW        equ 33
WIN_SCROLLBAR_INIT       equ 34
WIN_SCROLLBAR_DRAW       equ 35
WIN_LISTBOX_DRAW         equ 36
WIN_ENTRY_COUNT          equ 37

WIN_ERR_ARGUMENT         equ #20
WIN_ERR_VIDEO_MODE       equ #21
WIN_ERR_WINDOW           equ #22
WIN_ERR_BACKSTORE        equ #23
WIN_ERR_DEPTH            equ #24
WIN_ERR_UNSUPPORTED      equ #25
WIN_ERR_BUSY             equ #26
WIN_ERR_FONT             equ #27
WIN_ERR_MEMORY           equ #28

WIN_WORK_AUTO            equ #ff
WIN_TXT_ASCIIZ           equ 0
WIN_TXT_PASCAL           equ 1

; WinTheme (16 bytes).
WIN_THEME_SIZE           equ 16
WIN_TH_LIGHT             equ 0
WIN_TH_SHADOW            equ 1
WIN_TH_FACE              equ 2
WIN_TH_DESKTOP           equ 3
WIN_TH_TEXT              equ 4
WIN_TH_TEXT_DISABLED     equ 5
WIN_TH_FIELD_BG          equ 6
WIN_TH_FIELD_FG          equ 7
WIN_TH_CURSOR_BG         equ 8
WIN_TH_CURSOR_FG         equ 9
WIN_TH_PROGRESS          equ 10
WIN_TH_PROGRESS_FILL     equ 11
WIN_TH_SCROLL_TRACK      equ 12
WIN_TH_SCROLL_THUMB      equ 13
WIN_TH_FOCUS_MASK        equ 14
WIN_TH_RESERVED          equ 15

; WinRect (10 bytes).
WIN_RECT_SIZE            equ 10
WIN_RC_X                 equ 0
WIN_RC_Y                 equ 2
WIN_RC_WIDTH             equ 4
WIN_RC_HEIGHT            equ 6
WIN_RC_COLOR             equ 8
WIN_RC_FLAGS             equ 9
WIN_RC_SUNKEN            equ #01
WIN_RC_VERTICAL          equ #02

; WinLabel (12 bytes).
WIN_LABEL_SIZE           equ 12
WIN_LBL_X                equ 0
WIN_LBL_Y                equ 2
WIN_LBL_WIDTH            equ 4
WIN_LBL_HEIGHT           equ 6
WIN_LBL_ATTR             equ 8
WIN_LBL_FLAGS            equ 9
WIN_LBL_TEXT             equ 10
WIN_LABEL_LEFT           equ 0
WIN_LABEL_CENTER         equ 1
WIN_LABEL_RIGHT          equ 2
WIN_LABEL_ALIGN_MASK     equ #03
WIN_LABEL_FILL           equ #04
WIN_LABEL_CLIP           equ #08

; WinButton (12 bytes).
WIN_BUTTON_SIZE          equ 12
WIN_BTN_X                equ 0
WIN_BTN_Y                equ 2
WIN_BTN_WIDTH            equ 4
WIN_BTN_HEIGHT           equ 6
WIN_BTN_ATTR             equ 8
WIN_BTN_FLAGS            equ 9
WIN_BTN_TEXT             equ 10
WIN_BTN_GLYPH            equ #01
WIN_BTN_FOCUS            equ #02
WIN_BTN_PRESSED          equ #04
WIN_BTN_DISABLED         equ #08

; WinWindow (16 bytes).
WIN_WINDOW_SIZE          equ 16
WIN_WND_X                equ 0
WIN_WND_Y                equ 2
WIN_WND_WIDTH            equ 4
WIN_WND_HEIGHT           equ 6
WIN_WND_COLOR            equ 8
WIN_WND_FLAGS            equ 9
WIN_WND_COUNT            equ 10
WIN_WND_FOCUS            equ 11
WIN_WND_ITEMS            equ 12
WIN_WND_LAST_FOCUS       equ 14
WIN_WND_RESERVED         equ 15
WIN_WND_NOPANEL          equ #01
WIN_WND_SUNKEN           equ #02

; WinItem (8 bytes).
WIN_ITEM_SIZE            equ 8
WIN_ITEM_TYPE            equ 0
WIN_ITEM_FLAGS           equ 1
WIN_ITEM_ID              equ 2
WIN_ITEM_RESERVED        equ 3
WIN_ITEM_CONTROL         equ 4
WIN_ITEM_USER_DATA       equ 6

WIN_T_NONE               equ 0
WIN_T_LABEL              equ 1
WIN_T_FILL               equ 2
WIN_T_FRAME              equ 3
WIN_T_PANEL              equ 4
WIN_T_SEPARATOR          equ 5
WIN_T_BUTTON             equ 6
WIN_T_ICON               equ 7
WIN_T_PROGRESS           equ 8
WIN_T_SCROLLBAR          equ 9
WIN_T_LISTBOX            equ 10
WIN_T_EDIT               equ 11
WIN_T_ZONE               equ 12

WIN_IT_DIRTY             equ #01
WIN_IT_HIDDEN            equ #02
WIN_IT_DISABLED          equ #04
WIN_IT_HIT               equ #08
WIN_IT_FOCUSABLE         equ #10
WIN_IT_PRESS             equ #20
WIN_IT_REPEAT            equ #40
WIN_IT_HOVER             equ #80

; WinKey (4 bytes).
WIN_KEY_SIZE             equ 4
WIN_KEY_ASCII            equ 0
WIN_KEY_SCAN             equ 1
WIN_KEY_MODS             equ 2
WIN_KEY_ID               equ 3

; WinTrack (32 bytes).
WIN_TRACK_SIZE           equ 32
WIN_TRK_WINDOW           equ 0
WIN_TRK_KEYS             equ 2
WIN_TRK_KEY_COUNT        equ 4
WIN_TRK_OPTIONS          equ 5
WIN_TRK_EVENT            equ 6
WIN_TRK_ID               equ 7
WIN_TRK_INDEX            equ 8
WIN_TRK_PART             equ 9
WIN_TRK_MOUSE_X          equ 10
WIN_TRK_MOUSE_Y          equ 12
WIN_TRK_BUTTONS          equ 13
WIN_TRK_KEY_ASCII        equ 14
WIN_TRK_KEY_SCAN         equ 15
WIN_TRK_KEY_MODS         equ 16
WIN_TRK_RESERVED         equ 17
WIN_TRK_ITEM             equ 18
WIN_TRK_USER_DATA        equ 20
WIN_TRK_REPEAT_DELAY     equ 22
WIN_TRK_REPEAT_RATE      equ 23
WIN_TRK_STATE            equ 24

; WinCursor (4-byte header followed by BIOS-format pixels).
WIN_CURSOR_SIZE          equ 4
WIN_CUR_WIDTH            equ 0
WIN_CUR_HEIGHT           equ 1
WIN_CUR_HOT_X            equ 2
WIN_CUR_HOT_Y            equ 3

WIN_TRK_ANY_KEY          equ #01
WIN_TRK_OUTSIDE          equ #02
WIN_TRK_HALT             equ #04
WIN_TRK_SHOW_CUR         equ #08
WIN_TRK_TAB_FOCUS        equ #10

WIN_EV_NONE              equ 0
WIN_EV_LCLICK            equ 1
WIN_EV_RCLICK            equ 2
WIN_EV_REPEAT            equ 3
WIN_EV_HOTKEY            equ 4
WIN_EV_KEY               equ 5
WIN_EV_HOVER             equ 6
WIN_EV_LEAVE             equ 7
WIN_EV_OUTSIDE           equ 8
WIN_EV_FOCUS             equ 9

WIN_REPEAT_DELAY         equ 12
WIN_REPEAT_RATE          equ 3

; WinEdit (16 bytes).
WIN_EDIT_SIZE            equ 16
WIN_ED_X                 equ 0
WIN_ED_Y                 equ 2
WIN_ED_WIDTH             equ 4
WIN_ED_HEIGHT            equ 6
WIN_ED_ATTR              equ 8
WIN_ED_FLAGS             equ 9
WIN_ED_MAXLEN            equ 10
WIN_ED_LEN               equ 11
WIN_ED_CURSOR            equ 12
WIN_ED_SCROLL            equ 13
WIN_ED_BUFFER            equ 14

WIN_ED_FRAME             equ #01
WIN_ED_FOCUS             equ #02
WIN_ED_PASSWORD          equ #04

WIN_ED_ENTER             equ 0
WIN_ED_ESC               equ 1
WIN_ED_TAB               equ 2
WIN_ED_MOUSE             equ 3

; WinIcon (12 bytes).
WIN_ICON_SIZE            equ 12
WIN_ICO_X                equ 0
WIN_ICO_Y                equ 2
WIN_ICO_WIDTH            equ 4
WIN_ICO_HEIGHT           equ 6
WIN_ICO_FLAGS            equ 8
WIN_ICO_PAGE             equ 9
WIN_ICO_SLOT             equ 10
WIN_ICO_RESERVED         equ 11
WIN_ICO_KEYED            equ #01

; WinProgress (12 bytes).
WIN_PROGRESS_SIZE        equ 12
WIN_PG_X                 equ 0
WIN_PG_Y                 equ 2
WIN_PG_WIDTH             equ 4
WIN_PG_HEIGHT            equ 6
WIN_PG_FLAGS             equ 8
WIN_PG_PERCENT           equ 9
WIN_PG_LAST_PX           equ 10
WIN_PG_FRAME             equ #01

; WinScrollbar (22 bytes).
WIN_SCROLLBAR_SIZE       equ 22
WIN_SB_X                 equ 0
WIN_SB_Y                 equ 2
WIN_SB_WIDTH             equ 4
WIN_SB_HEIGHT            equ 6
WIN_SB_VISIBLE           equ 8
WIN_SB_TOTAL             equ 10
WIN_SB_FIRST             equ 12
WIN_SB_FLAGS             equ 14
WIN_SB_RESERVED          equ 15
WIN_SB_THUMB_POS         equ 16
WIN_SB_THUMB_LEN         equ 18
WIN_SB_LAST_POS          equ 20
WIN_SB_HORIZONTAL        equ #01
WIN_SB_ARROWS            equ #02
WIN_SB_MIN_THUMB         equ 4

WIN_SB_PART_BACK         equ 1
WIN_SB_PART_FORWARD      equ 2
WIN_SB_PART_PAGE_BACK    equ 3
WIN_SB_PART_PAGE_FORWARD equ 4
WIN_SB_PART_THUMB        equ 5

; WinTextRef (3 bytes) and WinListbox (28 bytes).
WIN_TEXT_REF_SIZE        equ 3
WIN_TXR_PAGE             equ 0
WIN_TXR_OFFSET           equ 1

WIN_LISTBOX_SIZE         equ 28
WIN_LB_X                 equ 0
WIN_LB_Y                 equ 2
WIN_LB_WIDTH             equ 4
WIN_LB_HEIGHT            equ 6
WIN_LB_ITEM_HEIGHT       equ 8
WIN_LB_ATTR_NORMAL       equ 9
WIN_LB_ATTR_CURSOR       equ 10
WIN_LB_FLAGS             equ 11
WIN_LB_TOTAL             equ 12
WIN_LB_FIRST             equ 14
WIN_LB_CURSOR            equ 16
WIN_LB_ITEMS             equ 18
WIN_LB_ITEMS_PAGE        equ 20
WIN_LB_RESERVED          equ 21
WIN_LB_SCROLLBAR         equ 22
WIN_LB_LAST_FIRST        equ 24
WIN_LB_LAST_CURSOR       equ 26
WIN_LB_FRAME             equ #01
WIN_LB_NOCURSOR          equ #02
WIN_LB_FOCUS             equ #04
WIN_LB_PAGED             equ #08
WIN_LB_PART_ROW          equ 1

WIN_BACKSTORE_MAX_PAGES  equ 4
WIN_BACKSTORE_MAX_DEPTH  equ 4
WIN_BACKSTORE_CHUNK      equ 256

WIN_STYLE_PALETTE        equ #01
WIN_STYLE_CLEAR          equ #02
WIN_STYLE_BOTH           equ #04

WIN_CAP_CORE             equ #0001
WIN_CAP_EDIT             equ #0002
WIN_CAP_LISTBOX          equ #0004
WIN_CAP_SCROLLBAR        equ #0008
WIN_CAP_PROGRESS         equ #0010
WIN_CAP_ICON             equ #0020
WIN_CAP_FOCUS            equ #0040
WIN_CAP_PASCAL_STR       equ #0080

WIN_CONFIG_SIZE          equ 20
WIN_CFG_STRUCT_SIZE      equ 0
WIN_CFG_DSS_MODE         equ 1
WIN_CFG_WIDTH            equ 2
WIN_CFG_HEIGHT           equ 4
WIN_CFG_VRAM_WINDOW      equ 6
WIN_CFG_CODE_WINDOW      equ 7
WIN_CFG_SCREEN           equ 8
WIN_CFG_BACKSTORE_PAGES  equ 9
WIN_CFG_BACKSTORE_DEPTH  equ 10
WIN_CFG_FONT_HEIGHT      equ 11
WIN_CFG_CAPABILITIES     equ 12
WIN_CFG_FONT_PAGE        equ 14
WIN_CFG_DATA_WINDOW      equ 15
WIN_CFG_ORIGIN_X         equ 16
WIN_CFG_ORIGIN_Y         equ 18
WIN_CFG_TEXT_FORMAT      equ 19
