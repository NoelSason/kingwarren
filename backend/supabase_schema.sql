create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null,
    username text not null unique,
    email text not null unique,
    seabucks integer not null default 0 check (seabucks >= 0),
    created_at timestamptz not null default timezone('utc', now())
);

alter table public.profiles enable row level security;

create policy "users_can_view_their_own_profile"
on public.profiles
for select
using (auth.uid() = id);

create policy "users_can_update_their_own_profile"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, display_name, username, email, seabucks)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'display_name', ''),
        coalesce(new.raw_user_meta_data ->> 'username', ''),
        new.email,
        0
    );

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.scans (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    store text not null default '',
    total numeric(10,2) not null default 0,
    ocean_score int not null default 0,
    seabucks_earned int not null default 0,
    item_count int not null default 0,
    items jsonb not null default '[]'::jsonb,
    created_at timestamptz not null default timezone('utc', now())
);

alter table public.scans enable row level security;

create policy "users_can_insert_own_scans"
on public.scans
for insert
with check (auth.uid() = user_id);

create policy "users_can_read_own_scans"
on public.scans
for select
using (auth.uid() = user_id);

create index if not exists scans_user_id_created_at_idx
    on public.scans (user_id, created_at desc);

create or replace function public.add_seabucks(amount int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
    new_balance int;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;
    update public.profiles
    set seabucks = seabucks + amount
    where id = auth.uid()
    returning seabucks into new_balance;
    return new_balance;
end;
$$;

grant execute on function public.add_seabucks(int) to authenticated;
