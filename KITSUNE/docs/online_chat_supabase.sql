-- KITSUNE online chat foundation.
-- Apply through Supabase migrations after reviewing policy, retention, and region settings.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  created_at timestamptz not null default now()
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  description text not null default '',
  is_private boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'client',
  created_at timestamptz not null default now(),
  primary key (room_id, user_id),
  check (role in ('client', 'moderator', 'officer', 'developer', 'owner'))
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz
);

create index if not exists messages_room_created_idx on public.messages(room_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.messages enable row level security;

create policy profiles_read_signed_in on public.profiles for select to authenticated using (true);
create policy profiles_write_self on public.profiles for all to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy rooms_read_members on public.rooms for select to authenticated using (not is_private or exists (select 1 from public.room_members m where m.room_id = rooms.id and m.user_id = auth.uid()));
create policy members_read_self on public.room_members for select to authenticated using (user_id = auth.uid());
create policy messages_read_members on public.messages for select to authenticated using (exists (select 1 from public.room_members m where m.room_id = messages.room_id and m.user_id = auth.uid()) and deleted_at is null);
create policy messages_insert_members on public.messages for insert to authenticated with check (author_id = auth.uid() and exists (select 1 from public.room_members m where m.room_id = messages.room_id and m.user_id = auth.uid()));
create policy messages_update_self on public.messages for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());

-- Role counts and privileged capabilities must be enforced with server-side functions,
-- not client role strings. Do not grant owner/developer/officer access from the APK.
