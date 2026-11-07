-- Резервные копии мира игрового сервера (0.54, 2026-11-08). Применено миграцией world_backups.
-- Сервер раз в час кладёт сюда сжатый файл мира (server_world.json → gzip → base64). Хранится 7 дней.
-- Ключа к базе у сервера нет: он сам создаёт случайный ключ (user://backup.key) и при первом запуске
-- регистрирует его ОТПЕЧАТОК (sha256) — только если в backup_keys пусто. Дальше копии принимаются только с этим ключом.
-- Таблицы закрыты: RLS включён, политик и прав у anon/authenticated нет — читать и писать можно только через функции.

create table public.backup_keys (
  hash text primary key check (hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now()
);
alter table public.backup_keys enable row level security;

create table public.world_backups (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  players int not null default 0,
  raw_bytes int not null default 0,
  data text not null
);
alter table public.world_backups enable row level security;
create index world_backups_created_at on public.world_backups (created_at desc);

-- Регистрация ключа сервера: принимается, только если ключа ещё нет. true — этот ключ зарегистрирован.
create function public.register_backup_key(key_hash text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if key_hash is null or key_hash !~ '^[0-9a-f]{64}$' then
    return false;
  end if;
  if not exists (select 1 from public.backup_keys) then
    insert into public.backup_keys (hash) values (key_hash) on conflict do nothing;
  end if;
  return exists (select 1 from public.backup_keys where hash = key_hash);
end $$;

-- Положить копию: ключ, сжатые данные (base64), сколько персонажей и байт до сжатия.
-- Не чаще раза в 50 минут, не больше 4 МБ; копии старше 7 дней удаляются.
create function public.put_world_backup(token text, data text, players int default 0, raw_bytes int default 0) returns text
language plpgsql security definer set search_path = '' as $$
begin
  if token is null or length(token) <> 64
     or not exists (select 1 from public.backup_keys k where k.hash = encode(sha256(convert_to(token, 'UTF8')), 'hex')) then
    return 'denied';
  end if;
  if data is null or length(data) < 16 or length(data) > 4 * 1024 * 1024 then
    return 'bad_size';
  end if;
  if exists (select 1 from public.world_backups w where w.created_at > now() - interval '50 minutes') then
    return 'too_soon';
  end if;
  insert into public.world_backups (players, raw_bytes, data)
    values (greatest(coalesce(players, 0), 0), greatest(coalesce(raw_bytes, 0), 0), data);
  delete from public.world_backups w where w.created_at < now() - interval '7 days';
  return 'ok';
end $$;

-- Последняя копия — для восстановления сервера, у которого нет своего файла мира. Только с ключом.
create function public.get_latest_world_backup(token text) returns json
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if token is null or length(token) <> 64
     or not exists (select 1 from public.backup_keys k where k.hash = encode(sha256(convert_to(token, 'UTF8')), 'hex')) then
    return null;
  end if;
  select w.created_at, w.data into r from public.world_backups w order by w.created_at desc limit 1;
  if not found then
    return null;
  end if;
  return json_build_object('created_at', r.created_at, 'data', r.data);
end $$;

revoke all on function public.register_backup_key(text) from public, anon, authenticated;
revoke all on function public.put_world_backup(text, text, int, int) from public, anon, authenticated;
revoke all on function public.get_latest_world_backup(text) from public, anon, authenticated;
grant execute on function public.register_backup_key(text) to anon;
grant execute on function public.put_world_backup(text, text, int, int) to anon;
grant execute on function public.get_latest_world_backup(text) to anon;
