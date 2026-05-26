# homework_ai

this app is to help students around the globe not only to solve their homewrok, but get understanging of how it solved

## Secure API key setup

Do not bundle `.env` in production builds. This app now reads config from `--dart-define`.

Run locally:

```bash
flutter run --dart-define=GROQ_API_KEY=your_key_here
```

Build release:

```bash
flutter build apk --release --dart-define=GROQ_API_KEY=your_key_here
```
