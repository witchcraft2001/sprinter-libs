# Спецификация GFX640 ABI 1.0

## 1. Назначение и режим

`GFX640.DLL` обслуживает только DSS-режим `#82`:

- 640×256 пикселей;
- packed 4bpp, цвет `0..15`;
- 320 байт на строку каждого буфера;
- buffer 0 имеет смещение `#000`, buffer 1 — `#140`;
- выбор строки выполняется через `PORT_Y=#89`;
- библиотека не включает и не выключает видеорежим.

Публичные координаты всегда пиксельные. В памяти high nibble соответствует
чётному/левому пикселю, low nibble — нечётному/правому:

```text
byte[x >> 1] = (pixel[x & ~1] << 4) | pixel[x | 1]
```

ABI сохраняет номера entry `0..35`, регистры и layout дескрипторов GFX320.
Точная nibble-прозрачность тайлов добавлена в entry `36..41`.
Зарезервированные entry: 3, 19 и 20.

## 2. Вызов и статус

DLL загружается и вызывается через libman. Аргументы передаются в `A`, `DE`,
`IX`, `IY`; `DE` указывает на packed-дескриптор там, где это указано ниже.
После успешного `LIBMAN.l_call` результат DLL находится в `A`:

| A | Значение |
|---:|---|
| `0` | успех |
| `#10` | `GFX_ERR_ARGUMENT` |
| `#11` | `GFX_ERR_VIDEO_MODE` (зарезервирован ABI) |
| `#12` | `GFX_ERR_WINDOW` |
| `#13` | `GFX_ERR_PAGE` |
| `#14` | `GFX_ERR_TILE` |
| `#15` | `GFX_ERR_PALETTE` |
| `#16` | `GFX_ERR_BUSY` |
| `#17` | `GFX_ERR_UNSUPPORTED` |

Carry для entry ≥1 не является каналом статуса GFX: сначала проверяется
ошибка диспетчера libman, затем `A`.

## 3. Цели, источники и флаги

Младшие два бита выбирают buffer:

| Значение | Назначение |
|---:|---|
| 0 | buffer 0 |
| 1 | buffer 1 |
| 2 | текущий front |
| 3 | текущий back |

`GFX_VRAM_ONLY=#04` запрещает обновление DRAM-зеркала назначения.
`GFX_KEY_FF=#08` для обычных entry означает аппаратную байтовую семантику:
записываемый `#FF` не меняет пару пикселей. В `*_transparent` этот же флаг делает
каждый nibble `#F` прозрачным; `#FF` по-прежнему обрабатывается аппаратно.
Без KEY индекс 15 всегда является обычным цветом.

KEY разрешён для tile/copy/move и специального `put_pixel`. Сплошные
`clear/fill_rect/draw_rect/hline/vline/line/scroll` возвращают
`GFX_ERR_UNSUPPORTED`. `put_pixel` с KEY и цветом 15 — успешный no-op.

При nibble read-modify-write исходный соседний nibble читается из
DRAM-зеркала. Поэтому частичная запись с `VRAM_ONLY` может восстановить
соседний пиксель, который ранее менялся только в VRAM. Это зафиксированное
ограничение ABI.

## 4. Выравнивание и границы

Safe-entry возвращают `GFX_ERR_ARGUMENT` при нарушении:

| Операция | Требование |
|---|---|
| `fill_rect`, `draw_rect` | чётные X и width |
| `hline` | чётные X и length |
| copy/move/restore | чётные source X, destination X и width |
| scroll | чётные X, width и signed `dx` |
| все safe tile-entry | чётный destination X |

`put_pixel`, `get_pixel`, `vline` и `line` принимают любой X `0..639`.
Y находится в `0..255`. Прямоугольник должен удовлетворять
`x+width<=640` и `y+height<=256`. Нулевой extent — успешный no-op после
проверки цвета, флагов и требований чётности.

`draw_tile_fast` не выполняет safe-проверки; корректные page table, slot,
`x<=608`, `y<=240` и чётный X являются предусловием вызывающей стороны.

## 5. Таблица entry

| Entry | Имя | Аргументы / результат |
|---:|---|---|
| 0 | `gfx_init` | hook libman; выбирает свободное VRAM-window |
| 1 | `gfx_free` | завершение |
| 2 | `gfx_set_vram_window` | E=1..3 |
| 3 | reserved | `GFX_ERR_UNSUPPORTED` |
| 4 | `gfx_get_version` | out DE=`#0100`, IX=capabilities |
| 5 | `gfx_get_config` | DE→`GfxConfig` |
| 6 | `gfx_clear` | A=color, E=flags |
| 7 | `gfx_fill_rect` | DE→`GfxFillRect` |
| 8 | `gfx_hline` | IX=x, IY=y, DE=length/flags, A=color |
| 9 | `gfx_vline` | IX=x, IY=y, DE=length/flags, A=color |
| 10 | `gfx_copy_rect` | DE→`GfxCopyRect` |
| 11 | `gfx_copy_buffer` | D=source, E=destination flags |
| 12 | `gfx_restore_rect` | DE→`GfxRestoreRect` |
| 13 | `gfx_palette_load256` | DE→RGB8[768], A=palette mask |
| 14 | `gfx_palette_load_range` | A=first, DE→RGB8, IX=count/mask |
| 15 | `gfx_palette_set` | A=index, D=R, E=G, IXL=B, IXH=mask |
| 16 | `gfx_fade_begin` | A=direction, D=duration, E=mask |
| 17 | `gfx_fade_step` | out E=1 active / 0 complete |
| 18 | `gfx_fade_cancel` | — |
| 19–20 | reserved | `GFX_ERR_UNSUPPORTED` |
| 21 | `gfx_swap_buffers` | — |
| 22 | `gfx_set_page_table` | DE→physical pages, IX=count 1..256 |
| 23 | `gfx_draw_tile` | DE=TileRef, IX=x, IY=y, A=flags |
| 24 | `gfx_draw_tile_fast` | те же регистры, preconditions |
| 25 | `gfx_draw_tile_span` | DE→`GfxTileSpan` |
| 26 | `gfx_draw_tilemap` | DE→`GfxTilemap` |
| 27 | `gfx_draw_metatile` | DE→`GfxMetatile` |
| 28 | `gfx_draw_rect` | DE→`GfxFillRect` |
| 29 | `gfx_put_pixel` | IX=x, IY=y, A=color, E=flags |
| 30 | `gfx_get_pixel` | IX=x, IY=y, E=source; out E=color |
| 31 | `gfx_line` | DE→`GfxLine` |
| 32 | `gfx_move_rect` | DE→`GfxCopyRect`, same-buffer memmove |
| 33 | `gfx_scroll_rect` | DE→`GfxScrollRect` |
| 34 | `gfx_draw_tile_list` | DE→`GfxTileList` |
| 35 | `gfx_draw_tile_clip` | регистры как entry 23 |
| 36 | `gfx_draw_tile_transparent` | регистры как entry 23 |
| 37 | `gfx_draw_tile_clip_transparent` | регистры как entry 23 |
| 38 | `gfx_draw_tile_span_transparent` | DE→`GfxTileSpan` |
| 39 | `gfx_draw_tile_list_transparent` | DE→`GfxTileList` |
| 40 | `gfx_draw_tilemap_transparent` | DE→`GfxTilemap` |
| 41 | `gfx_draw_metatile_transparent` | DE→`GfxMetatile` |

Цвет любого сплошного примитива выше 15 возвращает `GFX_ERR_ARGUMENT`.

## 6. Конфигурация и capabilities

`GfxConfig` имеет неизменный размер 16:

| Offset | Size | Поле / значение |
|---:|---:|---|
| 0 | 1 | struct size = 16 |
| 1 | 1 | required mode = `#82` |
| 2 | 2 | width = 640 |
| 4 | 2 | height = 256 |
| 6 | 1 | выбранное VRAM-window |
| 7 | 1 | source window = WIN0 |
| 8 | 1 | code window |
| 9 | 1 | mapping = source WIN0 |
| 10 | 2 | capabilities = `#01FF` |
| 12 | 1 | tile width = 32 |
| 13 | 1 | tile height = 16 |
| 14 | 1 | row-major layout = 0 |
| 15 | 1 | reserved = 0 |

Capabilities: accelerator, DRAM mirror, KEY_FF, double buffer, RGB8 palette,
fade, tiles, WIN0 source и `GFX_CAP_NIBBLE_KEY=#0100`. Значения
определены в `gfx640.inc`.

## 7. Packed length/flags

`hline` и `vline` используют младшие 10 бит `DE` для длины и биты 10..13
для четырёх флагов:

```text
length = DE & #03FF
flags  = (DE & #3C00) >> 10
DE     = length | (flags << 10)
```

Биты 14..15 обязаны быть нулевыми. Константы:
`GFX_LENGTH_MASK=#03FF`, `GFX_LENGTH_FLAGS_MASK=#3C00`,
`GFX_LENGTH_FLAGS_SHIFT=10`.

## 8. Дескрипторы

Все поля little-endian, структуры packed, хвостовые reserved-байты равны 0.
Размеры и offset-константы находятся в `gfx640.inc`.

### GfxFillRect / GfxDrawRect — 12 байт

`x:u16@0, y:u8@2, width:u16@3, height:u16@5, color:u8@7,
flags:u8@8, reserved[3]@9`.

### GfxCopyRect / GfxMoveRect — 12 байт

`source:u8@0, flags:u8@1, source_x:u16@2, source_y:u8@4,
destination_x:u16@5, destination_y:u8@7, width:u16@8, height:u16@10`.
Move требует один и тот же resolved buffer и сохраняет memmove-семантику.

### GfxRestoreRect — 8 байт

`x:u16@0, y:u8@2, width:u16@3, height:u16@5, target:u8@7`.
Источник — DRAM-зеркало выбранного buffer, назначение — его VRAM.

### GfxTileSpan — 8 байт

`refs:u16@0, count:u16@2, x:u16@4, y:u8@6, flags:u8@7`.
До 20 тайлов, `x+count*32<=640`.

### GfxTileItem / GfxTileList

Item имеет 5 байт: `ref:u16@0, x:u16@2, y:u8@4`.
List имеет 8 байт: `items:u16@0, count:u16@2, flags:u8@4,
reserved[3]@5`.

### GfxTilemap — 20 байт

`refs:u16@0, map_width:u16@2, map_height:u16@4, source_x:u16@6,
source_y:u16@8, draw_width:u16@10, draw_height:u16@12,
destination_x:u16@14, destination_y:u8@16, flags:u8@17,
reserved[2]@18`.

### GfxMetatile — 8 байт

`refs:u16@0, width:u8@2, height:u8@3, x:u16@4, y:u8@6,
flags:u8@7`.

### GfxLine — 8 байт

`x0:u16@0, y0:u8@2, x1:u16@3, y1:u8@5, color:u8@6, flags:u8@7`.

### GfxScrollRect — 16 байт

`x:u16@0, y:u8@2, width:u16@3, height:u16@5, dx:i16@7, dy:i16@9,
fill_color:u8@11, flags:u8@12, reserved[3]@13`.

## 9. Тайлы

TileRef не изменён: E=slot `0..63`, D=logical page `0..255`.
`gfx_set_page_table` копирует physical-page table внутрь DLL.

Тайл занимает ровно 256 байт:

- 32×16 пикселей;
- 16 строк по 16 байт;
- high nibble — левый пиксель пары;
- row-major, stride источника 16;
- 64 тайла на 16-КБ странице.

Полный тайл: чётный `x<=608`, `y<=240`. Экранная сетка 20×16.
Span/grid увеличивают X на 32; grid увеличивает Y на 16.
Clipped-entry принимают чётный `x<640` и любой `y`, обрезают только справа/снизу
и всегда переходят к следующей строке источника через 16 байт.

Каждая строка обычного entry выводится accelerator COPY длиной 16 байт.
После каждой команды немедленно выполняется `LD B,B`.
В exact-transparent entry внутренний цикл 16 packed-байт развёрнут; IFF и mapping
сохраняются один раз на целый тайл. `#F?/#?F` сливаются с DRAM-зеркалом,
а `#FF` записывается через аппаратный key alias.

Tilepack требует indexed PNG/BMP, размеры кратны 32×16, indices `0..15`.
В keyed-режиме каждый индекс 15 прозрачен, в том числе в одной половине packed-пары.
Маска непустых строк — little-endian u16, bit 15 соответствует первой строке, bit 0 — последней; для
opaque-пакета все строки считаются непустыми.

## 10. Copy, move, scroll и зеркало

После pixel-boundary и parity-проверок X/width делятся на два; accelerator и
row buffer работают с диапазоном до 320 байт. Row buffer DLL имеет 320 байт.
Same-buffer copy/move выбирает направление строк и использует row buffer,
поэтому пересечения имеют memmove-семантику. Scroll сначала переносит
пересекающуюся область, затем заполняет открытые полосы.

Источник copy/get всегда DRAM-зеркало. Изменения, сделанные `VRAM_ONLY`, там
не видны. Restore копирует зеркало обратно только в VRAM.

## 11. Palette и fade

Palette ABI остаётся 256×RGB8 и два bank mask:
`GFX_PAL_BUFFER0=1`, `GFX_PAL_BUFFER1=2`, `GFX_PAL_BOTH=3`.
В штатном режиме `#82` видимы первые 16 цветов выбранного банка; хранение и
fade по-прежнему обрабатывают все 256 entries.

Для load-range `IX` содержит count в битах 0..8 и palette mask в битах 9..10.
Fade имеет 33 уровня яркости, вызывается приложением через `fade_step` и не
владеет ISR. Palette update во время fade возвращает `GFX_ERR_BUSY`.

Библиотека нереентерабельна: вызывать любые GFX640 entry непосредственно из
ISR запрещено. Кадровый ISR приложения должен только обновлять frame
flag/counter; основной цикл, увидев новое кадровое событие, вызывает
`gfx_swap_buffers` и/или `gfx_fade_step`. Это сохраняет правила управления
окнами и совпадает с контрактом GFX320 ABI 1.0.

## 12. Аппаратная дисциплина

`gfx_init` выбирает WIN1..WIN3, не совпадающее с code window и stack window.
Tile source временно отображается в WIN0. В каждой аппаратной секции:

1. запоминается IFF и выполняется `DI`;
2. сохраняется page выбранного окна;
3. отображается alias `#50/#54/#58/#5C`;
4. accelerator block завершается немедленным `LD B,B`;
5. восстанавливается page, `PORT_Y=#C0` и исходный IFF.

Для tile дополнительно сохраняется и восстанавливается WIN0. Код DLL и стек
не могут находиться в WIN0 при tile-вызове. NMI exclusion — обязанность
приложения.

Область `#280..#3FF` экранной строки не должна изменяться: оба 320-байтных
buffer занимают только `#000..#27F`.

L0-код, state и buffers обязаны помещаться в одно 16-КБ окно; в исходнике
стоит assembler `assert $-gfx_image_start <= #4000`.

## 13. Проверка

`make host-test` проверяет frozen entry/descriptors, packing length/flags,
nibble order, 32×16 order, 64 tiles/page, u16 row masks, keyed half-pairs,
границы и parity paths. `make z80-test` выполняет source и relocatable DLL во
всех допустимых WIN1/WIN2/WIN3, проверяет config `#82/640×256/32×16`,
ошибки цвета/выравнивания и сохранение IFF.

`GFX640.EXE` проверяет X=638/639, все примитивы, opaque/keyed/clip tiles,
span/list/map/metatile, copy/move/scroll, restore, buffers и palette/fade.

На реальном Sprinter дополнительно проверяются:

- страницы `#50/#54/#58/#5C` и `PORT_Y`;
- прозрачные пары `#FF`;
- документированное поведение частичного `VRAM_ONLY`;
- оба palette bank;
- сохранность `#280..#3FF`;
- worst-case 32×16 exact-transparent tile loop; этот осознанно медленный
  путь может превышать `GFX_DI_BUDGET_US=200`.

После изменений в корневом `common/` обязательно повторяются `all`,
`verify`, host- и Z80-тесты GFX320; её ABI и поведение не меняются.
