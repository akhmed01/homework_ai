import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const PORT = Number.parseInt(process.env.PORT ?? '8080', 10);
const GROQ_API_KEY = (process.env.GROQ_API_KEY ?? '').trim();
const CLIENT_TOKEN = (process.env.CLIENT_TOKEN ?? '').trim();

const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '*')
  .split(',')
  .map((origin) => origin.trim())
  .filter((origin) => origin.length > 0);

const app = express();
app.set('trust proxy', 1);
app.use(helmet());
app.use(express.json({ limit: '10mb' }));

if (allowedOrigins.includes('*')) {
  app.use(cors());
} else {
  app.use(
    cors({
      origin(origin, callback) {
        if (!origin || allowedOrigins.includes(origin)) {
          callback(null, true);
          return;
        }
        callback(new Error('Origin not allowed by CORS policy'));
      },
      methods: ['GET', 'POST', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'X-Client-Token'],
    }),
  );
}

function requireClientToken(req, res, next) {
  if (!CLIENT_TOKEN) {
    next();
    return;
  }

  const incoming = (req.header('X-Client-Token') ?? '').trim();
  if (incoming !== CLIENT_TOKEN) {
    res.status(401).json({ error: 'Unauthorized client' });
    return;
  }

  next();
}

function isValidChatPayload(payload) {
  if (!payload || typeof payload !== 'object') {
    return false;
  }

  if (typeof payload.model !== 'string' || !payload.model.trim()) {
    return false;
  }

  if (!Array.isArray(payload.messages) || payload.messages.length === 0) {
    return false;
  }

  return true;
}

app.get('/health', (req, res) => {
  res.status(200).json({
    ok: true,
    service: 'homework-ai-backend',
    hasGroqKey: GROQ_API_KEY.length > 0,
  });
});

app.post('/chat', requireClientToken, async (req, res) => {
  try {
    if (!GROQ_API_KEY) {
      res.status(500).json({ error: 'Missing GROQ_API_KEY on server' });
      return;
    }

    if (!isValidChatPayload(req.body)) {
      res.status(400).json({
        error: 'Invalid request body. Expected model:string and messages:array',
      });
      return;
    }

    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(req.body),
    });

    const data = await response.text();
    res.status(response.status).send(data);
  } catch (error) {
    res.status(500).json({
      error: 'Proxy request failed',
      details: String(error),
    });
  }
});

app.use((error, req, res, next) => {
  if (error?.message === 'Origin not allowed by CORS policy') {
    res.status(403).json({ error: error.message });
    return;
  }
  next(error);
});

app.listen(PORT, () => {
  console.log(`Homework AI backend running on :${PORT}`);
});
