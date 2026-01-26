// Environment configuration
const config = {
  env: process.env.NODE_ENV || 'development',
  port: process.env.PORT || 3000,
  clientUrl: process.env.CLIENT_URL || 'http://localhost:3000',

  // Database
  mongoURI: process.env.MONGODB_URI || 'mongodb://localhost:27017/multilingual_chat',

  // JWT
  jwtSecret: process.env.JWT_SECRET || 'your-super-secret-jwt-key-here',
  jwtExpire: process.env.JWT_EXPIRE || '30d',

  // AI Services
  openaiApiKey: process.env.OPENAI_API_KEY,
  googleCloudApiKey: process.env.GOOGLE_CLOUD_API_KEY,
  azureSpeechKey: process.env.AZURE_SPEECH_KEY,
  azureSpeechRegion: process.env.AZURE_SPEECH_REGION,

  // File Upload
  maxFileSize: parseInt(process.env.MAX_FILE_SIZE) || 5000000,
  fileUploadPath: process.env.FILE_UPLOAD_PATH || './uploads',

  // Rate Limiting
  rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX) || 100,
  rateLimitWindow: parseInt(process.env.RATE_LIMIT_WINDOW) || 15,

  // CORS
  corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:3000'
};

module.exports = config;

