# Homework AI Backend

Secure proxy server for Groq API calls.

## 1) Setup

```bash
cd backend
npm install
```

Create `backend/.env` from `backend/.env.example` and fill:

- `GROQ_API_KEY=...` (required)
- `PORT=8080` (optional)
- `ALLOWED_ORIGINS=https://yourapp.web.app` (recommended for production)
- `CLIENT_TOKEN=...` (optional)

## 2) Run

```bash
npm start
```

Health check:

```bash
GET http://localhost:8080/health
```

Chat proxy endpoint:

```bash
POST http://localhost:8080/chat
```

## 3) Flutter app config

Point app to backend:

```bash
flutter run --dart-define=AI_PROXY_URL=http://localhost:8080/chat
```

If you set `CLIENT_TOKEN` on backend, also pass:

```bash
flutter run --dart-define=AI_PROXY_URL=http://localhost:8080/chat --dart-define=AI_PROXY_CLIENT_TOKEN=your_client_token
```

For production build:

```bash
flutter build apk --release --dart-define=AI_PROXY_URL=https://your-domain.com/chat
```
