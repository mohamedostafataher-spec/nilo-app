# Supabase (nilo-bottle)
- `migrations/0001_functions_snapshot.sql`: current RPC and trigger functions (security definer, authenticated-only).
- Going forward every DB change is added here as a numbered file before it is applied in the SQL editor.
- Still to export: table DDL, RLS policies and grants.
- Backup policy: free tier has no managed backups. Plan: export this folder plus a data export (Table editor CSV) monthly, stored outside the repo (data contains user content).
