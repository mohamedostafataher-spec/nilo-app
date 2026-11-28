# Nilo (نيلو)

A free Android tourist app: translation, a Nile social world (papyri messages, stories, friends), walkable 3D places, a private gallery and a daily journey. Built with Flutter. Backend: Supabase Free. Everything is free to run, no card needed.

## Build
- Flutter 3.27.4, Android only. Package `eg.nilo.nilo_app`.
- CI builds a signed APK on commits whose message contains `[build]` (`.github/workflows/build.yml`). The `Test` workflow runs analyze and unit tests on every push.
- Signing key and passwords live in GitHub Secrets only. Never commit them.
- Locally: `flutter pub get && flutter test`.

## Backend
- Supabase project `nilo-bottle`. The app uses the publishable key only. Tables use row level security; clients call RPC functions. See `supabase/` for the SQL and `docs/ARCHITECTURE.md`.
- Rewards (gems, XP, cards, riddles) are written by the server only.

## Rules of the project
- Free services only. Licences: CC0 / CC BY / public domain, credited in the Credits screen.
- 18+ self-declared, no links or phone numbers in messages, report and block, country code only, no coordinates stored.
- See `SECURITY.md`, `docs/ARCHITECTURE.md`, `docs/TECH_DEBT.md`, `CHANGELOG.txt`.
