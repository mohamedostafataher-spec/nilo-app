# Security

- Client holds only the publishable Supabase key. No secrets in the repo (audited).
- Row level security on all tables. RPCs are granted to `authenticated` only. Anonymous table and function access is revoked.
- Profile writes are limited to safe columns; bio, avatar and country go through a filtered RPC.
- Safety: 18+ self-declared, no links or phone numbers, report and block (blocks hide both ways), no contact with under-18, country code only.
- Delete account removes the server data and the stored files.
- Not done: 2FA, a general rate limiter, automated vulnerability scanning, a virus scan on uploads.
Report a problem through the Contact screen in the app.
