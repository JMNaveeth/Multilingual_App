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

create index if not exists idx_messages_sender_created
  on public.messages(sender_id, created_at desc);

create index if not exists idx_messages_receiver_created
  on public.messages(receiver_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.messages enable row level security;

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

-- Optional realtime for messages table
alter publication supabase_realtime add table public.messages;
