# Flow Support Mobile App

## Overview
Flutter mobile app for customer support agents to manage WhatsApp Business conversations via Twilio. Built for Enviable Investment (Nigerian transport/investment company).

## Architecture
- **State management**: Riverpod (StateNotifier pattern)
- **Routing**: GoRouter with shell navigation
- **API client**: Dio with JWT auth interceptor
- **Real-time**: Socket.IO for message delivery and status updates
- **Push**: Firebase Cloud Messaging
- **Storage**: SharedPreferences (auth), sqflite (message cache)

## Key Patterns

### Theme System
- `lib/config/theme.dart` — AppColors (light/dark), ThemeProvider singleton, BuildContext extension
- Access colors via `ThemeProvider.instance.colors.X` or `context.appColors.X`
- Brand colors (accent, danger, etc.) are static on AppColors: `AppColors.accent`
- Dynamic colors (background, textPrimary, etc.) come from ThemeProvider
- In AppBar widgets, don't set explicit colors — let foregroundColor handle it (green header in light mode needs white icons/text)

### PendingMessageService
- Singleton at `lib/services/pending_message_service.dart`
- **Map-based**: one pending message per conversation, fully independent
- Each conversation has its own timer — actions on one never affect another
- `pendingFor(conversationId)`, `hasPendingFor(conversationId)`, `sendNow(conversationId:)`, `cancelMessage(conversationId:)`, `editMessage(body, conversationId:)`
- Timer auto-dispatches after 120 seconds via `onSend` callback
- Only applies to text messages — media goes through uploadsProvider directly

### Message Status Flow
- Optimistic: message created with `queued` status
- Server responds with `sent` + Twilio SID
- Twilio webhooks update to `delivered`, `read`, `undelivered`, or `failed`
- `windowExpired` 400 from server: message marked as `undelivered` locally (not deleted)
- Conversation list preview shows correct status icon via `lastMessageStatus`

### 24h Window Enforcement
- Server blocks sends when WhatsApp 24h window expired (returns 400 `windowExpired: true`)
- App shows non-dismissible red banner at top of chat when expired
- Broadcast endpoint skips expired contacts (returns `skipped` array)
- Broadcast screen shows orange clock icon on expired contacts

### Conversation Independence (CRITICAL)
- Actions in one conversation must NEVER affect another
- PendingMessageService uses Map keyed by conversationId
- Send button checks `hasPendingFor(widget.conversationId)`, not global `hasPending`
- Input bar only blocks in the conversation with the pending message

## Project Structure
```
lib/
  config/theme.dart          — Theme system (AppColors, ThemeProvider, typography)
  models/                    — Data models (Message, Conversation, Contact, User)
  providers/                 — Riverpod state (conversations, messages, uploads, auth)
  screens/                   — Full-page screens
  services/                  — Singletons (API, socket, push, cache, pending message)
  widgets/                   — Reusable widgets (bubbles, input bar, wallpaper, etc.)
  router/app_router.dart     — GoRouter config
  app.dart                   — MaterialApp with theme
  main.dart                  — Entry point, Firebase init
```

## Server
- API: `http://52.208.133.222` (AWS EC2)
- SSH: `ssh -i ~/.ssh/enviable-key.pem ec2-user@52.208.133.222`
- Docker Compose at `~/enviable-whatsapp/`
- Restart: `docker-compose restart api`
- Logs: `docker-compose logs --tail=50 api`
- DB: `docker-compose exec -T db psql -U enviable_admin -d enviable_whatsapp`

## Build & Deploy
- APK: `flutter build apk --release`
- IPA: `flutter build ipa --release`
- Firebase distribution: `firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --project enviable-whatsapp --app 1:194728842921:android:60b8cdf4ba28658c7abbb8 --groups internal-testers --release-notes "..."`
- IPA via Transporter app to TestFlight
- Don't auto-build — wait for explicit instruction
- Always run `flutter test` before building
- Firebase project: `enviable-whatsapp`
- Android app ID: `1:194728842921:android:60b8cdf4ba28658c7abbb8`
- iOS app ID: `1:194728842921:ios:42930edd4c114ea37abbb8`
- Testers group: `internal-testers` (always include)

## Testing
- `flutter test` — 39 tests
- PendingMessageService: 20 tests including conversation independence
- Window expired handling: 19 tests (model, parsing, broadcast detection)
- Backend: `cd backend && npx jest` — 29 tests

## Git
- Mobile: https://github.com/enviabledev/flow_support_app.git
- Backend: https://github.com/enviabledev/flow_support_backend.git
- Firebase config files (google-services.json, GoogleService-Info.plist) are gitignored — not in repo

## Known Considerations
- Socket connections can flap (rapid connect/disconnect) — `onSend` callback must always point to current live ChatScreen
- Twilio sends `undelivered` and `sent` webhooks nearly simultaneously — DB uses atomic priority-based UPDATE to prevent race conditions
- `const` widgets cannot use `ThemeProvider.instance.colors.X` — remove `const` from any widget that references dynamic theme colors
