# Umwelt RP — техническая карта проекта (PROJECT_MAP)

Что где лежит, кто кого вызывает и что сломается при изменении файла. Составлено по исходному коду
(проверено 2026-11-03, после коммита 7c1d475; карта из файла и редактор — 2026-11-04, версия 0.19). Правила и процессы — в `docs/РУКОВОДСТВО.md`, история ошибок —
в `docs/BUGFIX_LOG.md`; здесь они не повторяются.

**Обновлять карту в том же коммите**, где добавляется, удаляется или переименовывается файл, меняется
`class_name`, связь между системами или сетевое сообщение.

---

## 1. Дерево файлов

```
Umwelt-RP/
├── project.godot              Настройки Godot 4.4: первая сцена — лаунчер, GL Compatibility, экран, тени. Без autoload
├── export_presets.cfg         Экспорт: «Android» (APK/пакет, без scripts/server_only, server, docs, *.md)
│                              и «Linux Server» (выделенный сервер, x86_64)
├── icon.png (+ .import)       Иконка приложения
├── CLAUDE.md                  Короткие обязательные инструкции для ИИ-разработчика
├── README.md, LICENSE         Описание и «все права защищены»
├── NEWS.md                    Первая строка — новость текущей версии (для истории изменений)
├── .gitignore
├── launcher/
│   ├── launcher.tscn          Сцена лаунчера (Control + скрипт)
│   └── launcher.gd            Лаунчер: обновления с GitHub Releases, кнопки «Играть»/«Офлайн-тест», версия
├── scenes/
│   └── main.tscn              Сцена игры (Node «Main» + scripts/main.gd)
├── scripts/                   Код игры (попадает в game.pck и в сервер)
│   ├── main.gd                Точка входа игры: режим из лаунчера, формы входа/персонажа, ключи запуска
│   ├── boot.gd                Boot: адрес сервера (из Engine meta) и публичные данные Supabase
│   ├── version.gd             Version.BUILD — номер сборки (подставляет CI)
│   ├── profile.gd             Profile: настройки телефона (uid, ник, графика) в user://settings.cfg
│   ├── account.gd             Аккаунт Supabase: регистрация, вход, сессия, персонаж (без class_name)
│   ├── net.gd                 Net: сеть ENet (сервер или клиент), Net.I
│   ├── game.gd                GameState: вся игровая логика, игроки, сохранение, сетевые снимки
│   ├── game_screen.gd         GameScreen: игровой экран (SOLO / CLIENT), ввод, приём снимков
│   ├── world.gd               GameWorld: карта из файла (load_map/map_data), проходимость, объекты, двери, окна
│   ├── props.gd               Объекты карты: каталог (фонарь, скамейка, гидрант…), столкновения, модели (без class_name)
│   ├── map_editor.gd          Редактор карты: офлайн, только владелец; черновик → Supabase map_drafts (без class_name)
│   ├── world_mesh.gd          WorldMesh: 3D-геометрия города по карте (чанки, объекты, крыши, двери; фонари — из объектов)
│   ├── world_view.gd          WorldView: 3D-сцена: камера, солнце, свет, игроки, эффекты
│   ├── character.gd           CharModel: персонаж Quaternius — скелет, анимации, части одежды, оружие
│   ├── items.gd               Items: предметы, одежда (части моделей), слоты, причёски, цвета
│   ├── hud.gd                 Hud: интерфейс поверх 3D (кнопки, джойстик, панели, часы, деньги)
│   ├── icons.gd               Icons: иконки предметов и пиктограммы — рисуются кодом
│   ├── mesher.gd              Mesher: построитель low-poly геометрии с цветом вершин
│   ├── saves.gd               Saves: сохранение офлайн-мира user://save.json (+ резервная копия)
│   ├── demo.gd                Demo: демо-сцены для скриншотов (--demo=…)
│   └── server_only/           НЕ попадает к игрокам (исключено из экспорта Android)
│       ├── server.gd          Выделенный сервер: подключения, вход по аккаунту, рассылка, автосохранение
│       ├── audit_test.gd      Автотесты механик (--audit), запускаются в CI перед сборкой
│       ├── nettest.gd         Сетевой тест: клиенты подключаются к серверу (--nettest=…)
│       └── authtest.gd        Проверка входа Supabase → сервер (--authtest=…), в CI auth-test.yml
├── maps/
│   └── city.json              Карта игры: ряды клеток символами, объекты, точка появления. Попадает в пакет и сервер
├── shaders/
│   └── world.gdshader         Шейдер города: цвет вершин, прорезание стен перед игроком, свечение окон ночью
├── assets/chars/              Модели персонажей Quaternius (CC0), извлечены скриптом docs/tools/extract_chars.gd
│   ├── LICENSE.txt            Источник и лицензия CC0
│   ├── m_base.scn, f_base.scn Скелет (62 кости) + AnimationPlayer с 13 анимациями — мужской / женский
│   ├── m/*.scn (36 файлов)    Части мужской модели: *_Head, *_Body, *_Legs/_Pants, *_Feet, Pistol
│   └── f/*.scn (27 файлов)    Части женской модели
├── server/
│   ├── setup.sh               Первичная установка сервера на Hetzner (пользователь, systemd, таймер, ufw)
│   └── update.sh              Автообновление сервера из релиза «latest» (таймер раз в 2 минуты; проверяет подпись манифеста)
├── docs/                      Не попадает в игру
│   ├── РУКОВОДСТВО.md         Руководство: правила, процессы, сервер, аккаунты, журнал, версии
│   ├── BUGFIX_LOG.md          Журнал ошибок BF-NNN
│   ├── PROJECT_MAP.md         Этот файл
│   ├── SUPABASE_MAP.md        База Supabase: таблицы, RLS, права, функции, миграции (проверено по самой базе)
│   ├── DATA_FLOW.md           Движение данных телефон ↔ сервер ↔ Supabase ↔ GitHub, утечки и дублирование
│   ├── TEST_COVERAGE.md       Покрытие автотестами: что проверяется, пробелы, ненадёжные проверки, план
│   └── tools/
│       ├── extract_chars.gd   Инструмент: извлечение частей моделей из glTF Quaternius (запуск вне проекта)
│       ├── map_format.py      Черновик карты из Supabase (JSON) → текст maps/city.json в принятом виде
│       └── verify_manifest.gd Проверка в CI: код лаунчера принимает подпись манифеста сборки, подменённый — нет
└── .github/workflows/
    ├── build.yml              Пуш в main → ключ подписи из секретов (+ открытый ключ обновлений в лаунчер) → автотесты (+ SCRIPT ERROR) → сетевой тест → game.pck, сервер, (APK при необходимости) → manifest.json + manifest.sig → релиз «latest»
    └── auth-test.yml          Проверка входа: сервер + бот Test_Bot через настоящий Supabase (пароль — секрет BOT_PASSWORD)
```

`*.uid` рядом со скриптами — служебные идентификаторы Godot 4.4, удалять нельзя. Ветка `gh-pages` (отдельно от
`main`) — страница «Почта подтверждена» для писем Supabase.

---

## 2. Классы и скрипты

| Файл | Класс / тип | Ответственность |
|---|---|---|
| `launcher/launcher.gd` | `extends Control`, без class_name | Манифест и пакеты с GitHub Releases: с 0.25 подпись манифеста (`signature_ok`, ключ `UPDATE_KEY_B64` подставляет CI; без подписи манифест не используется), SHA-256 пакетов, `load_resource_pack`, запуск `scenes/main.tscn`. Классы игры **не использует** (упоминаются только в комментарии) |
| `scripts/main.gd` | `extends Node` (сцена Main) | Создаёт `Net`; по ключам запускает сервер / автотесты / демо; иначе режим из Engine meta `start_mode`; формы входа, регистрации, создания персонажа (с выбором пола); возврат в лаунчер |
| `scripts/boot.gd` | `Boot` | `host()`, `port()` из Engine meta (по умолчанию 2.31.45.237:7777); `SUPABASE_URL`, `SUPABASE_KEY` (публичный publishable-ключ) |
| `scripts/version.gd` | `Version` | `BUILD` — сверяется клиентом и сервером в «привет» |
| `scripts/profile.gd` | `Profile` | Статические настройки: `uid`, `nick`, `low_gfx`; `load_profile()` / `save_profile()` |
| `scripts/account.gd` | без class_name, `preload` | Supabase REST: `sign_up`, `sign_in`, `refresh`, `load_character` (id, name), `create_character(name, gender)`, `explain` (ошибки по-русски), сессия в `user://account.cfg`; `check_admin()` (RPC `is_admin`, ответ в `user://editor.cfg`), `admin_cached()`; `logout()` — закрыть сессию в Supabase (вызывает проверка входа в CI) |
| `scripts/net.gd` | `Net` (Node, `Net.I`) | `serve`, `join`, `close`, `kick`, `send` (надёжный RPC, канал 0), `send_fast` (канал 1, надёжный); входящие — в `inbox` с полем `_from`; `server_relay = false` — клиенты не получают чужих пакетов и подключений через сервер; шифрование DTLS (с 0.24): `serve(port, max, tls)` без ключа не запускается, `join` всегда шифрует; `TLS_NAME`, `client_tls()` (без сверки сертификата), `server_tls(dir)` (ключ создаётся один раз) |
| `scripts/game.gd` | `GameState` + вложенные `Player`, `NetClock` | Игровой мир: игроки (карточка `Player`: позиция, здоровье, деньги, счёт, вещи, одежда `wear`, внешность `look`), движение, драка, нокаут и возрождение, одежда, двери, время (МСК), сохранение и миграции, снимки для сети (`state_for`, `events_for`, `apply_state`, `apply_events`), кто кого видит (`sees`, `building_at`) |
| `scripts/game_screen.gd` | `GameScreen` | Режимы `SOLO` (логика на телефоне) и `CLIENT` (логика на сервере, здесь — предсказание своего движения); шлёт `in`/`act`/`hello`; принимает `init`/`st`/`ev`/`bye`; проверка обновлений раз в 180 с |
| `scripts/world.gd` | `GameWorld` | Тайлы и их типы; карта из файла: `read_map_file`, `load_map` (с проверкой, при ошибке мир не меняется), `map_data`, `map_text`, символы клеток `MAP_CHARS`; объекты `props` и круги столкновений `prop_cols` (`index_props`); проходимость (`solid`, `circle_blocked` — стены и объекты), видимость по прямой (`los`: сквозь окно видно, пуля не проходит), окна и двери, здания (`compute_buildings`) |
| `scripts/props.gd` | без class_name, `preload` | `DEFS` (название, круги `col`), `ORDER` (палитра редактора), `colliders()`, `lamp_head()`, `build()` — модель объекта в `Mesher` |
| `scripts/map_editor.gd` | без class_name, `load()` из main | Камера сверху, инструменты Рука/Кисть/Прямоугольник/Рамка/Объект/Выбор/Спавн, отмена, черновик `user://map_draft.json`, «Пройтись», «Из игры», «Отправить» (POST `map_drafts`). Логика правок (`paint`, `rect`, `place_prop`, `move_prop`, `rotate_prop`, `delete_prop`, `set_spawn`, `undo`) отдельно от касаний |
| `scripts/world_mesh.gd` | `WorldMesh` | Чанки геометрии, стены, мебель, машины-декорации, деревья, объекты карты (`Props.build`), фонари (`lamps` из объектов, `refresh_lamps`), крыши, двери |
| `scripts/world_view.gd` | `WorldView` | 3D-узлы: камера (`cam_pitch`, 54° в игре), солнце и окружение по `darkness()`, фонари, модели игроков (`CharModel`), кровь, частицы, выстрелы; перевод джойстика в направление мира; для редактора — `hide_roofs`, `rebuild_static`, `mark_point`, `ground_point` |
| `scripts/character.gd` | `CharModel` | Загружает `assets/chars/<пол>_base.scn` и части; `set_wear()` по `Items.part_for/tint_for`; тон кожи; оружие на кости `Wrist.R`; выбор анимации в `pose(phase, moving, attack, weapon_id, lying, sneak)` |
| `scripts/items.gd` | `Items` | `DEFS` (еда, оружие, одежда с `parts`/`also`/`tint`), `SLOTS`, `BARE`, `HEADS`, `COLORS`, `START_WEAR`; инвентарь (`add_to`, `take`, `count`, `weight`) |
| `scripts/hud.gd` | `Hud` | Рисование интерфейса (`_draw`), касания, джойстик, панели `INV` / `PAUSE` / `GEAR`, сообщения, напоминание об обновлении; в паузе офлайна — «Редактор карты» (владелец) / «Вернуться в редактор» |
| `scripts/icons.gd` | `Icons` | `item()` — иконка предмета по id (цветные варианты — по основе), `glyph()` — пиктограммы |
| `scripts/mesher.gd` | `Mesher` | Треугольники, коробки, трубы, эллипсоиды с цветом вершин; альфа цвета = «вид» (стена/свечение) |
| `scripts/saves.gd` | `Saves` | Офлайн-сохранение: временный файл → основной, резервная копия, проверка формата |
| `scripts/demo.gd` | `Demo` | Демо-сцены (`--demo=editor` открывает редактор карты — main.gd): `inside`, `inv`, `night`, `evening`, `gear`, `outfit`, `crowd`, `knocked`, `armed`, `catalog` (своё время, `real_clock = false`) |
| `scripts/server_only/server.gd` | без class_name, `load()` | Ключи `--port`, `--max`, `--noauth`; клиенты (`Client`), «привет» и проверка сборки, вход через Supabase (`_verify` → `_enter`), выдача снимков (`_send_to`), автосохранение раз в 15 с (`AUTOSAVE`) с проверкой «читается обратно», `.bak` и часовые копии `SAVE_HOURLY`, загрузка по цепочке (`_load_world`), лог статистики; защита: `Bucket` (действия 10/с, пакеты движения 40/с), `too_big` (> 8 КБ — отключение), `valid_token`, `HELLO_WAIT` 5 с |
| `scripts/server_only/audit_test.gd` | без class_name | 89 проверок (стены, сеть, видимость игроков, шифрование канала, подпись обновлений, некорректные пакеты, рассылка событий всем, скорость по выносливости, защита сервера, сохранения и их миграции, карта из файла, объекты, редактор карты, одежда, внешность, время и др.), выход с кодом 1 при ошибке |
| `scripts/server_only/nettest.gd` | без class_name | Клиент-бот: подключается, ходит, считает «откаты» и видимых игроков; переменная `NT_HOST` — внешний сервер; идёт в самое свободное направление и проверяет пройденный путь и замирания; запускается в CI (`build.yml`, «Network test») |
| `scripts/server_only/authtest.gd` | без class_name | Вход ботом через `account.gd` и проверка, что сервер впустил |
| `shaders/world.gdshader` | шейдер | Параметры `player_pos`, `cam_back`, `cut`, `night` (задаёт `world_view.gd`) |

---

## 3. Связи между файлами

### Кто кого использует (проверено поиском по коду)

| Класс | Используют |
|---|---|
| `GameState` | main, game_screen, hud, world_view, saves, demo, server, audit_test |
| `GameWorld` | game, world_mesh, world_view, hud, demo, audit_test |
| `Items` | game, world, world_mesh, character, hud, icons, demo, audit_test |
| `Net` (`Net.I`) | main (создаёт), game_screen, hud, server, nettest, authtest |
| `Profile` | main, game_screen, hud, world_view, nettest |
| `Boot` | main, account, server |
| `Version` | game_screen, hud, server |
| `GameScreen` | main (создаёт), hud, nettest, authtest |
| `props.gd` | world, world_mesh, map_editor (через `preload`) |
| `map_editor.gd` | main (`load`), audit_test |
| `Hud` | game_screen (создаёт), main |
| `WorldView` | game_screen (создаёт) |
| `WorldMesh` | world_view |
| `CharModel` | world_view |
| `Mesher` | world_mesh, world_view, character (холодное оружие) |
| `Icons` | hud |
| `Saves` | main, game_screen, audit_test |
| `Demo` | main |
| `account.gd` | main, authtest, hud, map_editor (через `preload`) |

### Загрузка по пути

- `launcher.gd` → `change_scene_to_file("res://scenes/main.tscn")`.
- `main.gd` → `load("res://scripts/server_only/server.gd" | audit_test.gd | authtest.gd | nettest.gd")`,
  `preload("res://scripts/account.gd")`, назад — `res://launcher/launcher.tscn`.
- `world.gd`, `world_mesh.gd`, `world_view.gd`, `audit_test.gd` → `preload("res://scripts/world.gd")` (константы тайлов).
- `world_view.gd` → `load("res://shaders/world.gdshader")`.
- `world.gd` → `res://maps/city.json` (`GameWorld.MAP_PATH`, читает `GameState.load_official_map`).
- `main.gd` → `load("res://scripts/map_editor.gd")`; редактор и «Пройтись» — `user://map_draft.json`.
- `character.gd` → `res://assets/chars/<m|f>_base.scn`, `res://assets/chars/<m|f>/<Часть>.scn` (имена из `items.gd`).

### Данные лаунчер → игра (только Engine meta)

| Ключ | Пишет | Читает |
|---|---|---|
| `start_mode` (`server` / `solo`) | launcher | main |
| `server_host`, `server_port` | launcher (из манифеста) | boot |
| `pack_build` | launcher | launcher (возврат из игры), game_screen |
| `latest_build` | launcher | game_screen (напоминание об обновлении) |

### Файлы на устройстве и сервере

| Путь | Кто пишет |
|---|---|
| `user://pck/` (пакеты, `state.json`) | launcher |
| `user://settings.cfg` | profile |
| `user://account.cfg` | account |
| `user://editor.cfg` (может ли аккаунт отправлять карты) | account (`check_admin`) |
| `user://map_draft.json` (черновик карты) | map_editor |
| `user://save.json`, `save.bak.json` | saves (офлайн) |
| `user://dtls/dtls.key`, `dtls.crt` (ключ шифрования канала, с 0.24) | server (`Net.server_tls`, при первом запуске) |
| `user://server_world.json`, `server_world.bak.json`, `server_world.h00…h23.json` (часовые копии) | server (на Hetzner: `/srv/umwelt/data/godot/app_userdata/Umwelt RP/`) |

---

## 4. Архитектура

### Запуск

```
APK → launcher.tscn ─(манифест, пакеты, SHA-256)→ scenes/main.tscn (main.gd)
        │                                            ├─ «Играть»: форма входа (account.gd → Supabase) → GameScreen CLIENT + Net.join
        │                                            └─ «Офлайн-тест»: GameScreen SOLO (Saves / новый мир)
        │                                                 └─ пауза → «Редактор карты» (владелец) → map_editor.gd ⇄ «Пройтись» (SOLO на черновике)
Сервер: umwelt-server.x86_64 --headless -- --server → main.gd → server_only/server.gd (+ Net.serve)
CI:     godot --headless -- --audit | --nettest=… | --authtest=…  (main.gd → server_only/*)
```

### Клиент (телефон, режим CLIENT)

`GameScreen` каждые 50 мс шлёт `in` (направление, бег, своя позиция) через `send_fast`; действия — `act`
(`attack`, `use`, `wear`, `unwear`, `drop`, `interact`) через `send`. Своё движение предсказывается локально
(`move_player`), чужие игроки рисуются с задержкой по снимкам (`NetClock`, `push_snap`/`sample_snaps`).
`GameState` на телефоне — реплика (`is_replica = true`, `update()` не считает мир).

### Сервер

`server.gd` держит единственный настоящий `GameState`, вызывает `update()` каждый кадр, раздаёт каждому
свой снимок раз в 50 мс: другие игроки — в 20 клетках и не под чужой крышей (`SEE_R`, `sees`, `building_at`), выстрелы — в 40 (`VIEW_R`) (`state_for`), события по готовности и полные данные
игроков раз в 0.25 с (`events_for`), сохраняет мир раз в 15 с и при выходе игрока (не при остановке службы — BF-029). Кто вошёл —
решает Supabase: токен из «привет» проверяется запросом `/auth/v1/user`, затем `characters?select=id,name,gender`.
Ключ аккаунта в мире — `sb:<user_id>` в `GameState.uids`, ID игрока = `characters.id`.
Карта сервера — только `maps/city.json` из его сборки; из сохранения берутся лишь состояния дверей (`load_data`).
Игрок, оказавшийся в стене или объекте после смены карты, переставляется (`unstick` / точка появления).

### Карта и редактор (Supabase)

Полное устройство базы — `docs/SUPABASE_MAP.md`.

- `public.admins` — кто может отправлять карты (клиентам закрыта, политик нет); `public.is_admin()` — RPC.
- `public.map_drafts` — черновики карт: вставлять и читать свои может только админ (RLS). Читает Claude через
  Supabase и выпускает новой версией `maps/city.json`; игра эту таблицу не читает.

### Сетевые сообщения (поле `t`)

| `t` | Откуда → куда | Канал | Что |
|---|---|---|---|
| `hello` | клиент → сервер | надёжный (0) | `token`, `legacy`, `uid`, `nick`, `build` |
| `init` | сервер → клиент | 0 | `pid`, `seed`, `world` (`to_data_for`: `map` — `map_data()`: ряды клеток с дверями, объекты, точка появления; игроки, без `uids`) |
| `in` | клиент → сервер | быстрый (1) | `ts`, `mx`/`my`, `run`, `x`/`y`, `fx`/`fy`, `fs` (ввод, позиция, взгляд, номер отката) |
| `act` | клиент → сервер | 0 | действие игрока (с 0.22: не больше 10 в секунду, разом до 15; любое сообщение > 8 КБ — отключение) |
| `st` | сервер → клиент | 1 | время и игроки рядом (`state_for`): по 10 чисел — `id, x, y, fx, fy, atk, sneak, force_seq, hp, stamina`; `sh` — выстрелы рядом |
| `ev` | сервер → клиент | 0 | события, сообщения, данные игроков (`events_for`) |
| `bye` | сервер → клиент | 0 | отказ или выход с причиной (`why`) |
| `disconnect` | Net → свой inbox | — | разрыв соединения (создаёт `net.gd`) |

### Лаунчер и обновления

Релиз «latest»: `manifest.json` (build, min_apk, apk_hash, server, файлы с sha256), `game.pck`,
`umwelt-server.zip`, `umwelt.apk`. Новый APK нужен, только если изменился «отпечаток» в `build.yml`
(лаунчер, `project.godot`, `export_presets.cfg`, список `class_name`, версия Godot). Сервер берёт сборку
скриптом `server/update.sh`.

---

## 5. Где какие игровые системы

| Система | Основные места |
|---|---|
| Карточка игрока, ID, деньги, банковский счёт | `game.gd`: класс `Player`, `join_player`, `_rekey`, `_move_id`, `tag()`, `player_data`/`player_from` |
| Аккаунты, персонаж, пол | `account.gd`, `main.gd` (`_show_login`, `_show_create_character`), `server.gd` (`_verify`, `_enter`), Supabase `public.characters` |
| Движение, бег, присед | `game.gd`: `move_speed`, `move_player`, `_finish_player`; `world.gd`: `circle_blocked` |
| Драка, нокаут, возрождение | `game.gd`: `_attack`, `hit_player`, `knock_out`, `_respawn`; анимации — `character.gd` `pose()` |
| Одежда | `items.gd` (`DEFS` с `parts`, `SLOTS`, `BARE`, `COLORS`), `game.gd` (`_wear`, `_unwear`, `wear_from`), `character.gd` (`set_wear`), `hud.gd` (`_draw_gear`), `icons.gd` |
| Внешность (пол, причёска, кожа) | `game.gd`: `default_look`, `look_from`, `set_gender`; `items.gd`: `HEADS`; `character.gd`: `setup`, `_apply_tone` |
| Модели персонажей | `assets/chars/`, `docs/tools/extract_chars.gd` |
| Инвентарь, еда, аптечки, оружие | `items.gd`, `game.gd` (`_use`, `take`), `hud.gd` (`_draw_inv`) |
| Двери | `game.gd`: `_interact`, `find_interact`; `world.gd`; `world_mesh.gd`: `build_door` |
| Время и свет | `game.gd`: `msk_time`, `date_str`, `clock`, `darkness`, `real_clock`; `world_view.gd`: солнце, окружение, фонари; `hud.gd`: часы и дата |
| Город и его 3D | `maps/city.json`, `world.gd` (`load_map`, `map_data`), `world_mesh.gd`, `shaders/world.gdshader` |
| Объекты карты (фонари, скамейки…) | `props.gd` (каталог, столкновения, модели), `world.gd` (`props`, `prop_cols`, `circle_blocked`), `world_mesh.gd` (`build_chunk`, `refresh_lamps`) |
| Редактор карты | `map_editor.gd`, `main.gd` (`_open_editor`, `_on_editor_done`), `hud.gd` (`_editor_btn`), `account.gd` (`check_admin`), Supabase `admins`/`map_drafts`, `docs/tools/map_format.py` |
| Сохранение и миграции | `game.gd` (`SAVE_VERSION`, `migrate`, `load_data`, `to_data`), `saves.gd`, `server.gd` (`save_world`, `_load_world`) |
| Интерфейс | `hud.gd`, `icons.gd` |
| Обновления | `launcher.gd`, `game_screen.gd` (`_check_update`), `build.yml`, `server/update.sh` |
| Автотесты | `server_only/audit_test.gd`, `nettest.gd`, `authtest.gd`, `.github/workflows/*` |

---

## 6. Критически важные файлы

| Файл | Что затронет изменение |
|---|---|
| `launcher/launcher.gd`, `launcher.tscn` | Только с новым APK; ошибка — игроки не смогут обновиться. Нельзя использовать классы игры |
| `project.godot`, `export_presets.cfg` | Меняют отпечаток APK → новый APK у всех. Фильтр экспорта отвечает за то, что серверный код не попадёт к игрокам |
| Любой `class_name` (добавить, переименовать, удалить) | Тоже новый APK (список `class_name` входит в отпечаток) |
| `scripts/game.gd` | Логика и клиента, и сервера, формат сохранений и сети. Новое поле карточки — в `player_data`/`player_from`, публичное — в `player_public`. Смена смысла данных — `SAVE_VERSION` + `migrate` |
| `scripts/net.gd` | Связь всех со всеми; каналы и режимы доставки |
| `scripts/version.gd` | Сервер не пустит клиент другой сборки (номер ставит CI — руками не менять) |
| `scripts/boot.gd` | Адрес сервера и Supabase для всех клиентов |
| `scripts/items.gd` | id вещей хранятся в сохранениях; переименование или удаление id без миграции — потеря вещей. Имена частей должны существовать в `assets/chars` (проверяет автотест) |
| `assets/chars/*.scn` | Используются по именам из `items.gd` и `character.gd`; переименование ломает одежду |
| `maps/city.json` | Карта для всех: сервер и офлайн. Битый файл — сервер не загрузит город (проверяет автотест «Карта: …»). Символы клеток — `GameWorld.MAP_CHARS`; id объектов должны быть в `props.gd` |
| `scripts/props.gd` | id объектов записаны в карте: переименование или удаление id — карта перестанет загружаться |
| `scripts/server_only/server.gd` | Вход в игру, сохранение мира на сервере |
| `.github/workflows/build.yml` | Выпуск всего: пакет, сервер, APK. Ключ подписи — из секретов `ANDROID_KEYSTORE_B64`/`_PASS`, отпечаток сверяется; без него сборка останавливается |
| `server/update.sh`, `setup.sh` | Обновление сервера на Hetzner (общий сервер с sw-rpg) |
| `shaders/world.gdshader` | Вид всего города; параметры задаёт `world_view.gd` |

---

## 7. Неиспользуемое и устаревшее (проверено поиском вызовов)

Всё найденное ранее удалено в 0.17 (см. BUGFIX_LOG BF-022): поиск пути зомби (`compute_flow`, `flow`, `cost`),
`bashable`, обыск и лут (`containers`, `open_container`, `loot_for`, `Items.LOOT`, `Kind.MATERIAL`), баррикады,
прочность клеток (`tile_hp`), разбитые окна и выбитые двери с перелезанием (`_try_climb`, `climb_target`,
поля `climb`), `kills`, `GameState.day()`, демо `loot`, лишние иконки, устаревшие комментарии.
Номера тайлов 9 и 11 оставлены как `OLD_WINDOW_BROKEN`/`OLD_DOOR_BROKEN` — только для миграции сохранений v3
(`GameState.migrate`). Сейчас неиспользуемого кода не известно.

Файлов-сирот не найдено: все скрипты и сцены подключены, все `.scn` из `assets/chars` либо используются в
`items.gd`, либо входят в список частей скрипта извлечения.
