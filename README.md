# Sri Gokul Dham - Japa App

Files: index.html (app) · admin.html (admin dashboard) · config.js (keys) · schema.sql · admin_setup.sql

## One-time setup (Supabase)
1. SQL Editor -> run **schema.sql** (safe to re-run; existing data is kept).
2. Open the app and create your own account (index.html -> "Create new account").
3. Put that email into **admin_setup.sql**, run it. You are now an admin.
4. Authentication -> URL Configuration -> add your site URLs to **Redirect URLs**, e.g.
   `https://YOURNAME.github.io/**` (needed for the password-reset emails).

## Deploy
Upload index.html, admin.html, config.js (with your anon public key) to GitHub Pages / Netlify.
Admin dashboard: `https://your-site/admin.html`

## Notes
- Never put the service_role key in config.js - only the anon public key.
- Admin access is enforced by the database (Row Level Security), not by hiding the page.
