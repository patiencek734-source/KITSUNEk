# Online Chat Setup

KITSUNE remains usable as a local tracker without an account or backend configuration. The Chat tab only becomes online-capable when the Android build receives Supabase configuration through Dart defines.

## Supabase project

1. Create a Supabase project.
2. Apply `docs/online_chat_supabase.sql` after reviewing region, retention, moderation, and privacy settings.
3. Enable email OTP authentication in Supabase Auth.
4. Create at least one room and add authenticated users to `room_members`.
5. Configure server-side role functions and audit logging before assigning privileged roles. Never trust a role value supplied by the client.

## Local development build

From the repository root:

```powershell
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

The anon key is intended for client use, but Supabase Row Level Security must be enabled and reviewed. Never put a service-role key in the APK.

## Release build

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Do not commit project URLs or keys into source files. The Chat tab displays a local-only message when these defines are absent.

## Current client scope

The first client slice supports:

- Separate online chat account activation
- Email verification-code sign-in
- Secure local session token storage
- Room listing
- Recent room message history
- Sending messages
- Online sign-out
- Separation from local HRT, medication, trauma, journal, photo, lab, and support-note data

Realtime subscriptions, offline message outbox, reports, blocks, direct messages, moderation queues, role management, attachments, and push notifications require the next backend/client slices before production launch.
