begin;

create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_first_name text;
begin
  v_first_name := nullif(trim(coalesce(new.raw_user_meta_data->>'nome', new.raw_user_meta_data->>'first_name', '')), '');

  insert into public.profiles (
    id,
    first_name,
    last_name,
    email,
    whatsapp,
    status
  ) values (
    new.id,
    coalesce(v_first_name, split_part(coalesce(new.email, 'Usuária'), '@', 1), 'Usuária'),
    nullif(trim(coalesce(new.raw_user_meta_data->>'sobrenome', new.raw_user_meta_data->>'last_name', '')), ''),
    lower(coalesce(new.email, '')),
    nullif(trim(coalesce(new.raw_user_meta_data->>'whatsapp', '')), ''),
    case when new.email_confirmed_at is null then 'pending' else 'active' end
  )
  on conflict (id) do update
  set email = excluded.email,
      updated_at = now();

  return new;
end;
$$;

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
  update public.profiles
  set email = lower(coalesce(new.email, email)),
      status = case
        when new.banned_until is not null and new.banned_until > now() then 'blocked'
        when new.email_confirmed_at is not null and status = 'pending' then 'active'
        else status
      end,
      updated_at = now()
  where id = new.id;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_auth_user_created();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update of email, email_confirmed_at, banned_until on auth.users
for each row execute function public.handle_auth_user_updated();

create or replace function public.register_last_access()
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.profiles
  set last_access_at = now(), updated_at = now()
  where id = auth.uid();
$$;

revoke all on function public.handle_auth_user_created() from public;
revoke all on function public.handle_auth_user_updated() from public;
revoke all on function public.register_last_access() from public;
grant execute on function public.register_last_access() to authenticated;

commit;
