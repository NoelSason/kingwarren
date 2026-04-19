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
