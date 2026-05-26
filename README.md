# homework_ai

this app is to help students around the globe not only to solve their homewrok, but get understanging of how it solved

## Secure API key setup

Never ship `GROQ_API_KEY` inside the mobile app. APK/IPA can be reverse engineered.

Use a backend proxy in production:
1. App calls your backend (`AI_PROXY_URL`).
2. Backend stores `GROQ_API_KEY` in server secrets.
3. Backend calls Groq and returns response to app.

Backend server files are in `backend/`. Setup steps: `backend/README.md`.

Run locally:

```bash
flutter run --dart-define=GROQ_API_KEY=your_key_here
```

Build release:

```bash
flutter build apk --release --dart-define=AI_PROXY_URL=https://your-domain.com/chat
```

If backend `CLIENT_TOKEN` is enabled:

```bash
flutter build apk --release --dart-define=AI_PROXY_URL=https://your-domain.com/chat --dart-define=AI_PROXY_CLIENT_TOKEN=your_client_token
```
