require('dotenv').config();
const crypto = require('crypto');
const configuredSecret = process.env.JWT_SECRET;
if (process.env.NODE_ENV === 'production' && (!configuredSecret || configuredSecret.length < 32 || /default|your_|replace_|feelingtrip/i.test(configuredSecret))) {
  throw new Error('Production requires a random JWT_SECRET of at least 32 characters');
}

module.exports = {
  port: process.env.PORT || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  jwt: {
    secret: configuredSecret || crypto.randomBytes(32).toString('hex'),
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || 'postgres',
    name: process.env.DB_NAME || 'feelingtrip_db',
    connectionString: process.env.DATABASE_URL,
  },
  supabase: {
    url: process.env.SUPABASE_URL,
    key: process.env.SUPABASE_KEY,
    bucket: process.env.SUPABASE_STORAGE_BUCKET || 'feelingtrip-media',
  },
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME,
    apiKey: process.env.CLOUDINARY_API_KEY,
    apiSecret: process.env.CLOUDINARY_API_SECRET,
  },
  email: {
    user: process.env.EMAIL_USER ? process.env.EMAIL_USER.trim() : '',
    pass: process.env.EMAIL_APP_PASSWORD ? process.env.EMAIL_APP_PASSWORD.replace(/\s+/g, '') : '',
  },
  geminiApiKey: process.env.GEMINI_API_KEY,
  geoapifyApiKey: process.env.GEOAPIFY_API_KEY?.trim() || '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-3.1-flash-lite',
  geminiTimeoutMs: 30000,
  aiAllowFallback: process.env.AI_ALLOW_FALLBACK === 'true',
  sepayApiKey: process.env.SEPAY_API_KEY,
  sepayBankBins: JSON.parse(process.env.SEPAY_BANK_BINS || '{}'),
  bankhub: {
    environment: process.env.BANKHUB_ENVIRONMENT || 'sandbox',
    clientId: process.env.BANKHUB_CLIENT_ID,
    clientSecret: process.env.BANKHUB_CLIENT_SECRET,
    eventSecret: process.env.BANKHUB_EVENT_SECRET,
    ipnKey: process.env.BANKHUB_IPN_KEY,
    redirectUri: process.env.BANKHUB_REDIRECT_URI,
  },
};
