-- Run this ONCE, after schema.sql, to make yourself an admin.
-- Step 1: create your account normally in the app (index.html -> "Create new account").
-- Step 2: put that same email below, then run this in Supabase -> SQL Editor.
insert into admins (user_id)
select id from auth.users where lower(email) = lower('YOUR_ADMIN_EMAIL@example.com')
on conflict do nothing;

-- Check it worked (should return 1 row):
select u.email from admins a join auth.users u on u.id = a.user_id;
