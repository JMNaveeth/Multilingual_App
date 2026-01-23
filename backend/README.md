# Multilingual Chat Backend

Node.js backend for the AI-Powered Multilingual Video Chat Application.

## 🚀 Features

- **RESTful API**: Express.js with comprehensive endpoints
- **Real-time Communication**: Socket.IO for instant messaging and WebRTC signaling
- **Authentication**: JWT-based secure authentication
- **Database**: MongoDB with Mongoose ODM
- **Security**: Helmet, CORS, rate limiting, input validation
- **Scalability**: Modular architecture with clean separation

## 🛠️ Tech Stack

- **Runtime**: Node.js 16+
- **Framework**: Express.js
- **Real-time**: Socket.IO 4.x
- **Database**: MongoDB with Mongoose
- **Authentication**: JWT (jsonwebtoken)
- **Security**: Helmet, CORS, express-rate-limit
- **Validation**: Built-in validation with Mongoose
- **Password Hashing**: bcryptjs

## 📋 Prerequisites

- Node.js 16.0.0 or higher
- MongoDB 4.4 or higher
- npm 8.0.0 or higher

## 🚀 Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd multilingual-chat-app/backend

# Install dependencies
npm install
```

### 2. Environment Setup

```bash
# Copy environment file
cp .env.example .env

# Edit .env with your configuration
nano .env
```

### 3. Database Setup

```bash
# Start MongoDB (if using local instance)
mongod

# Or use MongoDB Atlas for cloud database
# Update MONGODB_URI in .env
```

### 4. Start Development Server

```bash
# Development mode with nodemon
npm run dev

# Production mode
npm start
```

The server will start on `http://localhost:3000` (or your configured PORT).

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment mode | `development` |
| `PORT` | Server port | `3000` |
| `CLIENT_URL` | Frontend URL for CORS | `http://localhost:3000` |
| `MONGODB_URI` | MongoDB connection string | `mongodb://localhost:27017/multilingual_chat` |
| `JWT_SECRET` | JWT signing secret | `your-secret-key` |
| `JWT_EXPIRE` | JWT expiration time | `30d` |
| `RATE_LIMIT_MAX` | Max requests per window | `100` |
| `RATE_LIMIT_WINDOW` | Rate limit window (minutes) | `15` |

## 📊 API Endpoints

### Authentication
```
POST   /api/auth/register     - User registration
POST   /api/auth/login        - User login
GET    /api/auth/me           - Get current user
PUT    /api/auth/profile      - Update user profile
POST   /api/auth/logout       - User logout
```

### Chat
```
GET    /api/chat/conversations           - Get conversations list
GET    /api/chat/conversations/:userId   - Get conversation with user
POST   /api/chat/messages                - Send message
PUT    /api/chat/conversations/:userId/read - Mark messages as read
DELETE /api/chat/messages/:messageId     - Delete message
```

### Users
```
GET    /api/users              - Get users list
GET    /api/users/:id          - Get user by ID
GET    /api/users/online       - Get online users
GET    /api/users/language/:lang - Get users by language
PUT    /api/users/status       - Update online status
```

### Health Check
```
GET    /health                 - Server health status
```

## 🔌 Socket.IO Events

### Authentication
```javascript
// Client sends
socket.emit('authenticate', { token: 'jwt-token' });

// Server responds
socket.on('authenticated', { user, message });
socket.on('unauthenticated', { message });
```

### Messaging
```javascript
// Send message
socket.emit('send_message', {
  receiverId: 'user-id',
  content: 'Hello!',
  type: 'text'
});

// Receive message
socket.on('new_message', messageData);

// Message status
socket.on('message_sent', messageData);
socket.on('messages_read', { readerId, timestamp });
```

### Video Calling (WebRTC)
```javascript
// Initiate call
socket.emit('call_user', {
  userToCall: 'user-id',
  signalData: signal,
  from: 'caller-id',
  name: 'Caller Name'
});

// Receive call
socket.on('call_user', { signal, from, name });

// Answer call
socket.emit('answer_call', { to: 'caller-id', signal });

// Call accepted
socket.on('call_accepted', signal);

// End call
socket.emit('end_call', { to: 'user-id' });
socket.on('call_ended');
```

### AI Translation
```javascript
// Start translation
socket.emit('start_translation', {
  targetUserId: 'user-id',
  language: 'en'
});

// Send audio chunk
socket.emit('translation_audio', {
  targetUserId: 'user-id',
  audioData: audioBuffer,
  language: 'en'
});

// Receive translated text
socket.on('receive_subtitle', {
  from: 'user-id',
  text: 'translated text',
  originalLanguage: 'en',
  targetLanguage: 'es'
});

// Receive translated audio
socket.on('receive_translated_audio', {
  from: 'user-id',
  audioData: translatedAudio,
  language: 'es'
});
```

### User Status
```javascript
// User comes online
socket.on('user_online', { userId, user });

// User goes offline
socket.on('user_offline', { userId, lastSeen });

// Typing indicators
socket.emit('typing_start', { receiverId: 'user-id' });
socket.emit('typing_stop', { receiverId: 'user-id' });
socket.on('user_typing', { userId, isTyping });
```

## 🗄️ Database Models

### User Model
```javascript
{
  name: String,
  email: String (unique),
  password: String (hashed),
  preferredLanguage: String,
  profileImageUrl: String,
  isOnline: Boolean,
  lastSeen: Date,
  socketId: String,
  createdAt: Date,
  updatedAt: Date
}
```

### Message Model
```javascript
{
  sender: ObjectId (ref: User),
  receiver: ObjectId (ref: User),
  content: String,
  type: String (text|image|audio|video),
  status: String (sent|delivered|read),
  mediaUrl: String,
  metadata: Object,
  createdAt: Date,
  updatedAt: Date
}
```

## 🔒 Security

- **JWT Authentication**: Stateless authentication with secure tokens
- **Password Hashing**: bcrypt with 12 salt rounds
- **Rate Limiting**: 100 requests per 15-minute window
- **CORS**: Configured for specific origins
- **Helmet**: Security headers for XSS protection
- **Input Validation**: Comprehensive validation with Mongoose
- **SQL Injection Protection**: MongoDB with parameterized queries

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch
```

## 📦 Deployment

### PM2 (Production)
```bash
# Install PM2 globally
npm install -g pm2

# Start with PM2
pm2 start src/server.js --name "multilingual-chat"

# Save PM2 configuration
pm2 save
pm2 startup
```

### Docker
```dockerfile
FROM node:16-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
EXPOSE 3000

CMD ["npm", "start"]
```

## 📈 Monitoring

- **Health Check**: `/health` endpoint for load balancer checks
- **Logging**: Morgan middleware for HTTP request logging
- **Error Handling**: Centralized error handling with detailed logging
- **Performance**: Compression middleware for response optimization

## 🔧 Development

### Project Structure
```
backend/
├── src/
│   ├── config/          # Configuration files
│   ├── controllers/     # Route controllers
│   ├── middleware/      # Custom middleware
│   ├── models/          # Mongoose models
│   ├── routes/          # API routes
│   ├── services/        # Business logic services
│   ├── utils/           # Utility functions
│   └── server.js        # Main server file
├── tests/               # Test files
├── .env                 # Environment variables
├── package.json         # Dependencies
└── README.md           # Documentation
```

### Scripts
```json
{
  "start": "node src/server.js",
  "dev": "nodemon src/server.js",
  "test": "jest",
  "test:watch": "jest --watch",
  "test:coverage": "jest --coverage"
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 📞 Support

For support or questions, please open an issue on GitHub.
