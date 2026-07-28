# GFX320

English version of this document: [README.md](README.md).

`GFX320.DLL` — библиотека 2D-графики для Sprinter в режиме DSS `#81`
(320×256, 256 цветов). Она предоставляет готовые графические возможности
программам на ассемблере, C, Pascal и любых других языках, умеющих вызывать
DLL через libman: приложению не нужно самостоятельно программировать
видеоконтроллер, страницы VRAM, палитру или блиттер — оно вызывает функции
библиотеки по номерам. Внутри библиотека использует аппаратный акселератор
Sprinter, но это деталь реализации, а не предмет ABI.

## Состав поставки

| Файл | Назначение |
|---|---|
| `GFX320.DLL` | сама библиотека — единственный файл, нужный приложению |
| `gfx320.inc` | публичные константы и смещения дескрипторов для sjasmplus |
| `bindings/sdcc/` | заголовок и библиотека для C (SDCC) |
| `bindings/tpascal/` | include для Turbo Pascal |
| `examples/` | примеры вызова на C и Pascal, описание в `examples/README.md` |
| `GFX320.EXE` | визуальный тест библиотеки; приложениям **не нужен** |
| `specs.md` | полное ТЗ: регистровый ABI и аппаратные контракты |

## Функциональность (ABI 1.0)

Номера entry — в [gfx320.inc](gfx320.inc), полные сигнатуры — в
[specs.md](specs.md) §7.

- **Инициализация и конфигурация** — `gfx_init`/`gfx_free` (вызываются
  libman автоматически), `gfx_set_vram_window` (2), `gfx_get_version` (4),
  `gfx_get_config` (5).
- **Заливки и линии** — `gfx_clear` (6), `gfx_fill_rect` (7), `gfx_hline`
  (8), `gfx_vline` (9), `gfx_draw_rect` (28), `gfx_line` (31, Брезенхэм).
- **Пиксели** — `gfx_put_pixel` (29), `gfx_get_pixel` (30).
- **Двойная буферизация и копирование** — `gfx_copy_rect` (10),
  `gfx_copy_buffer` (11), `gfx_restore_rect` (12, восстановление фона из
  DRAM-зеркала), `gfx_swap_buffers` (21), `gfx_move_rect` (32),
  `gfx_scroll_rect` (33).
- **Палитра RGB8** — `gfx_palette_load256` (13), `gfx_palette_load_range`
  (14), `gfx_palette_set` (15).
- **Fade** — `gfx_fade_begin` (16), `gfx_fade_step` (17), `gfx_fade_cancel`
  (18): пошаговое затемнение/проявление на 33 уровнях яркости; шаги
  вызываются из кадрового ISR приложения, библиотека не захватывает
  прерывания.
- **Тайлы 16×16 (row-major)** — `gfx_set_page_table` (22), `gfx_draw_tile`
  (23), `gfx_draw_tile_fast` (24), `gfx_draw_tile_clip` (35), пакетные
  `gfx_draw_tile_span` (25), `gfx_draw_tile_list` (34), `gfx_draw_tilemap`
  (26), `gfx_draw_metatile` (27).
- **Прозрачность и зеркало** — флаги `GFX_KEY_FF` (аппаратный пропуск байтов
  `#FF`) и `GFX_VRAM_ONLY` (запись мимо DRAM-зеркала) у тайлов и копирования.

## Как вызывать (ABI кратко)

Библиотека загружается загрузчиком libman
(`sources/libman/libman/libman.asm`; имя `libman13.asm` — совместимый
синоним). Загрузчик сам ищет DLL в каталоге EXE:

```asm
        ld hl,libname        ; "GFX320.DLL",0
        ld a,3               ; окно для DLL (WIN3)
        call LIBMAN.l_load
        jp c,load_error      ; причина в LIBMAN.l_reason / l_dss_error
        ld (handle),hl

        ld hl,(handle)
        ld a,0               ; аргументы функции: A, DE, IX, IY
        ld e,GFX_TARGET_FRONT
        ld b,GFX_CLEAR       ; номер entry из gfx320.inc
        call LIBMAN.l_call
        jp c,dispatch_error  ; ошибка диспетчера libman
        or a
        jp nz,gfx_error      ; статус GFX320: 0 — успех, #10..#17 — ошибка
```

Правила:

- аргументы передаются в `A`, `DE`, `IX`, `IY`; крупные структуры — упакованным
  дескриптором по `DE` (смещения полей — в `gfx320.inc`);
- статус функции возвращается в `A` (`0` — успех, коды `GFX_ERR_*`
  `#10..#17`); флаг CF диспетчер libman использует для собственных ошибок,
  у entry `>=1` он не входит в публичный ABI;
- перед рисованием приложение само включает режим `#81`; библиотека видеорежим
  не меняет;
- для тайлов приложение выделяет страницы DSS (`DSS #3D`), получает их
  физические номера (BIOS `#C5`) и передаёт таблицу в `gfx_set_page_table`.

Готовые примеры: [examples/sdcc/example.c](examples/sdcc/example.c),
[examples/tpascal/example.pas](examples/tpascal/example.pas) и полный
ассемблерный сценарий [test.asm](test.asm).

## Ограничения и безопасность

- Тайловые вызовы на время операции подключают страницу-источник в WIN0 под
  `DI`: DLL и текущий стек должны быть вне WIN0, NMI на время операции
  исключается приложением.
- Рисование с `GFX_VRAM_ONLY` не попадает в DRAM-зеркало, поэтому невидимо
  для `get_pixel` и источников copy/move/scroll.
- Не выводите текст через DSS-консоль при активном режиме `#81`: текстовый
  экран и знакогенератор лежат в том же поле VRAM, печать портит картинку.
  Ждите клавишу молча (`DSS #30`), печатайте после восстановления режима.
- Полные аппаратные контракты — в [specs.md](specs.md) §15.

## Сборка и проверка

```sh
make -C gfx320 all        # DLL, визуальный тест, библиотека SDCC
make -C gfx320 verify     # проверка контейнера L0
make -C gfx320 host-test  # python-тесты ABI и упаковщика тайлов
make -C gfx320 z80-test   # исполнение DLL в эмуляторе по адресам WIN1..WIN3
make -C gfx320 benchmark  # build/GFXBENCH.EXE
make -C gfx320 release    # verify + тесты + обновление GFX320.DLL/EXE
```

Требуются `sjasmplus`, инструменты SDCC (`sdcc`, `sdar`), `sprinter-mkdll` и
исходники загрузчика libman. По умолчанию Makefile берёт загрузчик из
соседнего репозитория `sources/libman` (`../../libman/libman`); другие пути
задаются переменными `LIBMAN_MKDLL=...` и `LIBMAN_DIR=...`. Результаты
сборки — в `gfx320/build/`.

## Визуальный тест

`GFX320.EXE` нужен только для проверки библиотеки на железе или в эмуляторе:
положите его рядом с `GFX320.DLL` и запустите. Тест включает режим `#81`,
загружает палитру, рисует все примитивы и тайлы, проверяет копирование
буферов, восстановление фона и fade, затем молча ждёт клавишу и
восстанавливает исходный режим. Ошибки печатаются с кодами
(`l_reason`/`l_dss_error`/статус GFX/этап теста) уже после возврата в
текстовый режим.

## Бенчмарк

`build/GFXBENCH.EXE` — отдельная сборка того же теста **только для замера
производительности**: визуальное демо пропускается, экран очищается и
выводятся четыре полосы-результата. Подробности и интерпретация — в
[BENCHMARK.ru.md](BENCHMARK.ru.md). Замеры на реальном железе обязательны
перед включением дополнительных оптимизаций рендера.

## Упаковщик тайлов

Установите зависимости из `requirements-dev.txt`, затем конвертируйте
индексированный PNG/BMP в страницы тайлов:

```sh
python3 gfx320/tools/tilepack.py assets.png build/tiles \
  --keyed --transparent-index 0 --nonempty-rows \
  --metatile-width 2 --metatile-height 2
```

Инструмент создаёт 16-КБ файлы `pageNN.bin`, little-endian `TileRef`,
row-major tilemap, 768-байтную RGB-палитру и JSON-манифест.
