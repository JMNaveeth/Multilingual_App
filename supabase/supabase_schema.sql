-- Run this in Supabase SQL Editor

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name text not null,
  preferred_language text not null default 'en',
  profile_image_url text,
  is_online boolean not null default false,
  last_seen timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  content text not null default '',
  type text not null default 'text',
  status text not null default 'sent',
  media_url text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.call_history (
  id text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  peer_user_id uuid not null references public.profiles(id) on delete cascade,
  peer_name text not null,
  peer_profile_image_url text,
  call_type text not null default 'voice',
  direction text not null check (direction in ('incoming', 'outgoing')),
  result text not null check (result in ('completed', 'missed', 'declined', 'cancelled')),
  started_at timestamptz not null,
  ended_at timestamptz,
  duration_seconds integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_sender_created
  on public.messages(sender_id, created_at desc);

create index if not exists idx_messages_receiver_created
  on public.messages(receiver_id, created_at desc);

create index if not exists idx_call_history_user_started
  on public.call_history(user_id, started_at desc);

alter table public.profiles enable row level security;
alter table public.messages enable row level security;
alter table public.call_history enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles
  for select
  to authenticated
  using (true);

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "messages_select_own_conversations" on public.messages;
create policy "messages_select_own_conversations"
  on public.messages
  for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "messages_insert_sender_only" on public.messages;
create policy "messages_insert_sender_only"
  on public.messages
  for insert
  to authenticated
  with check (auth.uid() = sender_id);

drop policy if exists "call_history_select_own" on public.call_history;
create policy "call_history_select_own"
  on public.call_history
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "call_history_insert_own" on public.call_history;
create policy "call_history_insert_own"
  on public.call_history
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "call_history_update_own" on public.call_history;
create policy "call_history_update_own"
  on public.call_history
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "call_history_delete_own" on public.call_history;
create policy "call_history_delete_own"
  on public.call_history
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Auto-create profile row whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    email,
    name,
    preferred_language,
    is_online,
    created_at,
    updated_at
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'name', split_part(coalesce(new.email, 'User'), '@', 1), 'User'),
    coalesce(new.raw_user_meta_data->>'preferred_language', 'en'),
    false,
    now(),
    now()
  )
  on conflict (id) do update set
    email = excluded.email,
    name = excluded.name,
    preferred_language = excluded.preferred_language,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Storage RLS Policies for avatars bucket
-- Allow authenticated users to upload their own profile images
create policy "Allow authenticated users to upload profile images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars' and
  (storage.foldername(name))[1] = 'profile_images'
);

-- Allow public read access to profile images
create policy "Allow public to read profile images"
on storage.objects
for select
to public
using (
  bucket_id = 'avatars' and
  (storage.foldername(name))[1] = 'profile_images'
);

-- Allow authenticated users to read profile images
create policy "Allow authenticated users to read profile images"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars' and
  (storage.foldername(name))[1] = 'profile_images'
);

-- Optional realtime for messages table (safe to rerun)
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'messages'
    ) then
      alter publication supabase_realtime add table public.messages;
    end if;

    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'call_history'
    ) then
      alter publication supabase_realtime add table public.call_history;
    end if;
  end if;
end
$$;
