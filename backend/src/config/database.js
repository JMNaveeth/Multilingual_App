const mongoose = require('mongoose');

const connectDB = async () => {
  const allowWithoutDb =
      process.env.ALLOW_NO_DB === 'true' ||
      process.env.NODE_ENV === 'development';
  try {
    const mongoURI = process.env.MONGODB_URI || 'mongodb://localhost:27017/multilingual_chat';

    const conn = await mongoose.connect(mongoURI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log(`🗄️  MongoDB Connected: ${conn.connection.host}`);

    // Handle connection events
    mongoose.connection.on('error', (err) => {
      console.error('MongoDB connection error:', err);
    });

    mongoose.connection.on('disconnected', () => {
      console.log('MongoDB disconnected');
    });

    // Graceful shutdown
    process.on('SIGINT', async () => {
      await mongoose.connection.close();
      console.log('MongoDB connection closed through app termination');
      process.exit(0);
    });

  } catch (error) {
    console.error('Database connection error:', error);
    if (allowWithoutDb) {
      console.warn('⚠️ Continuing without MongoDB (development fallback mode).');
      return null;
    }
    throw error;
  }
};

module.exports = connectDB;

