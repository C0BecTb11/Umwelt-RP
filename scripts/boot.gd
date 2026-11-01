class_name Boot
extends RefCounted
## Куда подключаться. Лаунчер кладёт адрес сервера из манифеста в Engine meta,
## отсюда игра его читает. Лаунчер сам этот класс не загружает (иначе после обновления
## осталась бы старая версия в памяти) — передача только через Engine meta.

const DEFAULT_HOST := "2.31.45.237"
const DEFAULT_PORT := 7777

static func host() -> String:
	return str(Engine.get_meta("server_host", DEFAULT_HOST))

static func port() -> int:
	return int(Engine.get_meta("server_port", DEFAULT_PORT))

## Supabase (аккаунты). Адрес и publishable-ключ публичные — их и так видно в любом клиенте;
## доступ к данным ограничивают правила RLS в базе.
const SUPABASE_URL := "https://fhsjkenwbgncajzjvcxx.supabase.co"
const SUPABASE_KEY := "sb_publishable_gaxWk8-dSkgYlDXmI70-iw_juZbkq2Z"
