-- Umwelt RP: удаление аккаунта (BF-044). Вставить целиком в Supabase → SQL Editor → Run.
-- Ничего существующего не меняет: добавляет журнал удалений, функцию «удалить мой аккаунт»
-- и список отпечатков удалённых аккаунтов для игрового сервера.

create table public.account_deletions (
  id_hash text primary key,
  deleted_at timestamptz not null default now()
);
alter table public.account_deletions enable row level security;
revoke all on table public.account_deletions from anon, authenticated;
comment on table public.account_deletions is 'sha256(id) удалённых аккаунтов для игрового сервера; 90 дней';

create function public.record_account_deletion() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.account_deletions (id_hash)
  values (encode(pg_catalog.sha256(convert_to(old.id::text, 'UTF8')), 'hex'))
  on conflict (id_hash) do update set deleted_at = now();
  delete from public.account_deletions where deleted_at < now() - interval '90 days';
  return old;
end $$;
revoke execute on function public.record_account_deletion() from public, anon, authenticated;

create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute function public.record_account_deletion();

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'нужно войти в аккаунт' using errcode = '42501';
  end if;
  delete from auth.users where id = uid;
end $$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

create function public.deleted_accounts() returns table (h text)
language sql stable security definer set search_path = '' as $$
  select d.id_hash from public.account_deletions d order by d.deleted_at desc limit 5000;
$$;
revoke execute on function public.deleted_accounts() from public;
grant execute on function public.deleted_accounts() to anon, authenticated;
