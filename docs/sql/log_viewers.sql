-- Кто может открыть лог-чекер администратора (0.55, 2026-11-08). Применено миграцией log_viewers.
-- Отдельный список, а не admins: логи — не для всех администраторов (решение владельца, «чтоб не сливали»).
-- Первым вписан владелец (единственная строка admins на 2026-11-08). Добавить человека — только SQL
-- (insert into public.log_viewers (user_id) values ('<uuid>')), через игру/API — нельзя.

create table public.log_viewers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.log_viewers enable row level security;

insert into public.log_viewers (user_id) select user_id from public.admins;

-- «Допущен ли я к лог-чекеру» — только про себя (аргументов нет)
create function public.is_log_viewer() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.log_viewers where user_id = auth.uid())
$$;
revoke all on function public.is_log_viewer() from public, anon, authenticated;
grant execute on function public.is_log_viewer() to authenticated;
