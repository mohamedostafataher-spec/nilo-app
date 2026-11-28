# Architecture

Flutter app, one flat `lib/` folder grouped by feature file:
- Shell: `main.dart` (app, theme, error hooks), `navbar.dart`, `home.dart`, `settings.dart`, `i18n.dart` (EN/AR strings, `L()`).
- Social: `bottles.dart` (Supabase client `Sb`, papyri send/catch/thread), `stories.dart`, `friends.dart`, `gallery.dart`, `profile.dart`, `auth.dart`.
- Engagement: `daily.dart` (journey, cards, levels, frames), `shop.dart`, `quests.dart`.
- 3D and maps: `places.dart`, `vr.dart`, `earth.dart`, `globe.dart`.
- Health and cache: `health.dart` (local error log, perf watcher), `cache.dart`.

Patterns: static client `Sb` for the backend, `Passport` and `Ui` for local state, `setState` plus `ValueNotifier` in screens.

Backend rule: the client never writes rewards or permissions. It calls RPC functions (`journey_claim`, `card_reveal`, `catch_specific`, `shop_buy`, ...) that run as security definer, check `auth.uid()`, age gate and blocks, and are granted to `authenticated` only. Anonymous access is revoked.

Known weak spots are in `docs/TECH_DEBT.md`.
