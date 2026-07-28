; GFX320.DLL public MVP constants for sjasmplus clients.
GFX_INIT            equ 0
GFX_FREE            equ 1
GFX_SET_VRAM_WINDOW equ 2
GFX_GET_VERSION     equ 4
GFX_GET_CONFIG      equ 5
GFX_CLEAR           equ 6
GFX_FILL_RECT       equ 7
GFX_HLINE           equ 8
GFX_VLINE           equ 9
GFX_SET_PAGE_TABLE  equ 22
GFX_DRAW_TILE       equ 23
GFX_DRAW_TILE_FAST  equ 24
GFX_DRAW_TILE_SPAN  equ 25
GFX_DRAW_TILE_LIST  equ 34

GFX_ERR_ARGUMENT    equ #10
GFX_ERR_VIDEO_MODE  equ #11
GFX_ERR_WINDOW      equ #12
GFX_ERR_PAGE        equ #13
GFX_ERR_TILE        equ #14
GFX_ERR_PALETTE     equ #15
GFX_ERR_BUSY        equ #16
GFX_ERR_UNSUPPORTED equ #17

GFX_TARGET_BUF0     equ 0
GFX_TARGET_BUF1     equ 1
GFX_TARGET_FRONT    equ 2
GFX_TARGET_BACK     equ 3
GFX_VRAM_ONLY       equ #04
GFX_KEY_FF          equ #08

GFX_CAP_ACCEL       equ #0001
GFX_CAP_DRAM_MIRROR equ #0002
GFX_CAP_KEY_FF      equ #0004
GFX_CAP_DOUBLE_BUF  equ #0008
GFX_CAP_TILES       equ #0040
GFX_CAP_WIN0_SOURCE equ #0080

GFX_CONFIG_SIZE     equ 16
GFX_CFG_STRUCT_SIZE equ 0
GFX_CFG_DSS_MODE    equ 1
GFX_CFG_WIDTH       equ 2
GFX_CFG_HEIGHT      equ 4
GFX_CFG_VRAM_WINDOW equ 6
GFX_CFG_SOURCE_WIN  equ 7
GFX_CFG_CODE_WIN    equ 8
GFX_CFG_MAPPING     equ 9
GFX_CFG_CAPS        equ 10
GFX_CFG_TILE_W      equ 12
GFX_CFG_TILE_H      equ 13
GFX_CFG_TILE_LAYOUT equ 14

GFX_FILL_RECT_SIZE  equ 12
GFX_FR_X             equ 0
GFX_FR_Y             equ 2
GFX_FR_WIDTH         equ 3
GFX_FR_HEIGHT        equ 5
GFX_FR_COLOR         equ 7
GFX_FR_FLAGS         equ 8

; GfxTileSpan has no reserved tail: offsets 0..7 are the complete descriptor.
GFX_TILE_SPAN_SIZE   equ 8
GFX_TS_REFS          equ 0
GFX_TS_COUNT         equ 2
GFX_TS_X             equ 4
GFX_TS_Y             equ 6
GFX_TS_FLAGS         equ 7

GFX_TILE_LIST_SIZE   equ 8
GFX_TL_ITEMS         equ 0
GFX_TL_COUNT         equ 2
GFX_TL_FLAGS         equ 4
GFX_TILE_ITEM_SIZE   equ 5
GFX_TI_REF           equ 0
GFX_TI_X             equ 2
GFX_TI_Y             equ 4
