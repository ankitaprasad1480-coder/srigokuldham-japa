create table if not exists japa_logs (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  day date not null,
  rounds int not null check (rounds between 1 and 64),
  primary key (user_id, day)
);
alter table japa_logs enable row level security;
create policy "own rows select" on japa_logs for select using (auth.uid() = user_id);
create policy "own rows insert" on japa_logs for insert with check (auth.uid() = user_id);
create policy "own rows update" on japa_logs for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on japa_logs for delete using (auth.uid() = user_id);
