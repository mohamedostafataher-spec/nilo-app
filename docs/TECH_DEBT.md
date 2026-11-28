# Technical debt
1. About 168 empty `catch (_)` blocks hide errors. Plan: log through `Health.log`.
2. `bottles.dart` (1100+ lines) and `home.dart` hold too much. Plan: split by feature.
3. No service layer between screens and the backend.
4. DB changes were applied by hand. Plan: `supabase/migrations`.
5. Tests cover only pure logic. No UI or integration tests.
6. Accessibility labels, light theme and a real paging layer are missing.
