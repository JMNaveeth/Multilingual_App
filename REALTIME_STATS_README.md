# Real-Time Stats Implementation

## Overview
This implementation converts the home page from displaying random numbers to showing **real-time statistics** from your backend database.

## Features Implemented

### 📊 Real-Time Statistics
- **Active Users**: Shows users online in the last 15 minutes
- **Total Messages**: Real-time count of all messages
- **Total Groups**: Live count of group chats
- **Auto-Refresh**: Updates every 5 seconds automatically

### 🎨 UI Enhancements
- **Live Indicators**: Green "Live" badge on each stat card
- **Loading States**: Shimmer effect while fetching data
- **Error Handling**: Retry button if connection fails
- **Icons**: Visual icons for each stat category

### 🔧 Backend Implementation
- **New API Endpoint**: `/api/stats` for app-wide statistics
- **User Stats**: `/api/users/:userId/stats` for user-specific data
- **Optimized Queries**: Database indexes for fast queries
- **Models Updated**: Message, User, and Group schemas

## Files Created/Modified

### Flutter (Frontend)
1. **`lib/models/stats.dart`** - Stats data model
2. **`lib/services/stats_service.dart`** - Service for fetching stats
3. **`lib/providers/stats_provider.dart`** - Riverpod providers for state management
4. **`lib/screens/home/home_screen.dart`** - Updated to use real-time data

### Node.js (Backend)
1. **`backend/src/routes/stats.js`** - New stats API endpoints
2. **`backend/src/models/Group.js`** - New Group model
3. **`backend/src/models/Message.js`** - Updated with isRead and IDs
4. **`backend/src/models/User.js`** - Added lastActive field
5. **`backend/src/server.js`** - Registered stats routes

## How It Works

### Data Flow
```
Flutter App → Stats Service → Backend API → MongoDB
     ↓                                         ↓
Stats Provider ← Real-time Stream ← Database Query
     ↓
Home Screen (Updates UI)
```

### Auto-Refresh Mechanism
- Uses `Timer.periodic` to fetch stats every 5 seconds
- Streams updates to UI via Riverpod `StreamProvider`
- Automatic cleanup when screen is disposed

### Backend Statistics Calculation
```javascript
// Active Users: Online in last 15 minutes
const activeUsers = await User.countDocuments({
  lastActive: { $gte: fifteenMinutesAgo },
  isOnline: true
});

// Total Messages
const totalMessages = await Message.countDocuments();

// Total Groups
const totalGroups = await Group.countDocuments();
```

## API Endpoints

### GET /api/stats
Returns app-wide statistics
```json
{
  "activeUsers": 24,
  "totalMessages": 156,
  "totalGroups": 12,
  "lastUpdated": "2026-01-27T10:30:00.000Z"
}
```

### GET /api/users/:userId/stats
Returns user-specific statistics
```json
{
  "activeUsers": 8,
  "totalMessages": 42,
  "totalGroups": 3,
  "unreadMessages": 5,
  "lastUpdated": "2026-01-27T10:30:00.000Z"
}
```

## Configuration

### Change Refresh Interval
Edit `lib/services/stats_service.dart`:
```dart
static const Duration refreshInterval = Duration(seconds: 5); // Change this
```

### Change Backend URL
Edit `lib/providers/stats_provider.dart`:
```dart
final statsServiceProvider = Provider<StatsService>((ref) {
  final service = StatsService(baseUrl: 'http://your-backend-url');
  return service;
});
```

## Testing

### Start Backend
```bash
cd backend
npm start
```

### Start Flutter App
```bash
flutter run
```

### Verify Real-Time Updates
1. Open the app home screen
2. Watch the stats cards with "Live" badges
3. Create messages/groups in another session
4. Stats should update within 5 seconds

## Troubleshooting

### Stats Show Zero
- **Check**: Backend server is running
- **Check**: MongoDB is connected
- **Check**: Database has data (users, messages, groups)

### Stats Don't Update
- **Check**: No firewall blocking requests
- **Check**: Backend URL is correct
- **Check**: Network connectivity

### Error Loading Stats
- **Action**: Tap the refresh button
- **Check**: Console logs for error details
- **Check**: Backend logs for API errors

## Performance Optimization

### Database Indexes
All queries use indexed fields for optimal performance:
```javascript
messageSchema.index({ createdAt: -1 });
userSchema.index({ isOnline: 1, lastActive: -1 });
groupSchema.index({ members: 1 });
```

### Caching (Future Enhancement)
Consider adding Redis caching:
```javascript
const cachedStats = await redis.get('app:stats');
if (cachedStats) return JSON.parse(cachedStats);
// ... fetch from DB and cache
await redis.setex('app:stats', 5, JSON.stringify(stats));
```

## Next Steps

### Potential Enhancements
1. **WebSocket Integration**: Push updates instead of polling
2. **User-Specific Stats**: Show personalized statistics
3. **Charts & Graphs**: Visualize trends over time
4. **Activity Feed**: Show recent messages/groups
5. **Notifications**: Alert on significant stat changes

### WebSocket Example (Future)
```dart
// In stats_service.dart
void connectWebSocket() {
  final socket = io('http://localhost:3000');
  socket.on('stats_update', (data) {
    final stats = AppStats.fromJson(data);
    _statsController.add(stats);
  });
}
```

## Security Considerations

- Stats are public app-level data (no authentication required)
- User-specific stats require authentication token
- Rate limiting applied via express-rate-limit
- Input validation on userId parameter

## License
Part of Multilingual Chat App project
