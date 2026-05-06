const supabase = require('../config/supabase');
const aiTranslationService = require('./aiTranslationService');
const jwt = require('jsonwebtoken');

const SUPPORTED_LANGUAGE_CODES = new Set([
  'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ja', 'ko', 'zh', 'hi', 'ar', 'ta', 'te', 'kn', 'ml'
]);

const normalizeLanguage = (language, fallback = 'en') => {
  if (!language || typeof language !== 'string') return fallback;
  const normalized = language.toLowerCase().trim();
  return SUPPORTED_LANGUAGE_CODES.has(normalized) ? normalized : fallback;
};

const resolveUserPreferredLanguage = async (userId, fallback = 'en') => {
  if (!userId) return fallback;
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('preferred_language')
      .eq('id', userId)
      .single();
    
    if (error || !data) return fallback;
    return normalizeLanguage(data.preferred_language, fallback);
  } catch (error) {
    console.error(`Language lookup failed for user ${userId}:`, error.message);
    return fallback;
  }
};

const verifySocketToken = (token) => {
  if (!token) return null;
  const jwtSecret = process.env.JWT_SECRET;
  if (token.startsWith('ey') && jwtSecret) {
    try {
      const decoded = jwt.verify(token, jwtSecret);
      return decoded.id || decoded.userId || decoded.sub || null;
    } catch (err) {
      console.warn('⚠️ JWT verification failed:', err.message);
      return null;
    }
  }
  return token; // Dev fallback
};

const activeUsers = new Map(); // userId -> socketId
const socketToUser = new Map(); // socketId -> userId

const initializeSocket = (io) => {
  io.on('connection', (socket) => {
    console.log(`🔌 New connection: ${socket.id}`);

    socket.on('authenticate', async (data) => {
      try {
        const { token } = data;
        const userId = verifySocketToken(token);
        if (!userId) {
          socket.emit('unauthenticated', { message: 'Invalid token' });
          return;
        }

        const { data: user } = await supabase.from('profiles').select('*').eq('id', userId).single();
        
        activeUsers.set(userId, socket.id);
        socketToUser.set(socket.id, userId);
        socket.join(userId);

        socket.emit('authenticated', {
          user: { id: userId, name: user?.name || "User", preferredLanguage: user?.preferred_language || 'en' }
        });
        socket.broadcast.emit('user_online', { userId });
      } catch (error) {
        socket.emit('unauthenticated', { message: 'Auth failed' });
      }
    });

    socket.on('send_message', async (data) => {
      try {
        const { receiverId, content, type = 'text', metadata, senderLanguage, receiverLanguage } = data;
        const senderId = socketToUser.get(socket.id);
        if (!senderId) return;

        const sLang = normalizeLanguage(senderLanguage, 'en');
        const rLang = normalizeLanguage(receiverLanguage, 'en');
        
        // Always attempt translation to the receiver's language
        const result = await aiTranslationService.translateText(content, null, rLang);
        const translatedContent = result.text;
        const detectedSource = result.detected || sLang;

        const messagePayload = {
          id: Date.now().toString(),
          senderId, receiverId, content, type,
          metadata: { 
            ...metadata, 
            translatedContent, 
            originalLanguage: detectedSource, 
            targetLanguage: rLang 
          },
          createdAt: new Date()
        };

        const rSocketId = activeUsers.get(receiverId);
        if (rSocketId) io.to(rSocketId).emit('new_message', messagePayload);
        socket.emit('message_sent', messagePayload);

        // Async save/update to Supabase
        const clientMessageId = metadata?.clientMessageId;
        
        const saveToDb = async (attempt = 1) => {
          if (clientMessageId) {
            const { data, error } = await supabase.from('messages')
              .update({ metadata: messagePayload.metadata })
              .eq('metadata->>clientMessageId', clientMessageId)
              .select();
              
            if (error) {
              console.error('DB update error:', error);
            } else if (!data || data.length === 0) {
              // Message might not be inserted yet by the frontend, retry after 500ms
              if (attempt < 3) {
                setTimeout(() => saveToDb(attempt + 1), 500);
              } else {
                // Fallback to insert if update fails after retries
                supabase.from('messages').insert({
                  sender_id: senderId,
                  receiver_id: receiverId,
                  content,
                  type,
                  metadata: messagePayload.metadata
                }).then(({error}) => { if(error) console.error('DB save error:', error); });
              }
            }
          } else {
            supabase.from('messages').insert({
              sender_id: senderId,
              receiver_id: receiverId,
              content,
              type,
              metadata: messagePayload.metadata
            }).then(({error}) => { if(error) console.error('DB save error:', error); });
          }
        };

        saveToDb();

      } catch (error) {
        console.error('Send message error:', error);
      }
    });

    socket.on('send_call_text', async (data) => {
      const { targetUserId, text, sourceLanguage, targetLanguage, shouldSpeak = true, isFinal = true } = data;
      const userId = socketToUser.get(socket.id);
      if (!userId || !text) return;

      const startedAt = Date.now();
      try {
        const sLang = normalizeLanguage(sourceLanguage, 'en');
        const rLang = normalizeLanguage(targetLanguage, 'en');

        // 1. FAST TEXT TRANSLATION
        const result = await aiTranslationService.translateText(text.trim(), sLang, rLang);
        const translated = result.text;
        const detectedSource = result.detected || sLang;
        
        const latencyMs = Date.now() - startedAt;
        const rSocketId = activeUsers.get(targetUserId);

        if (rSocketId) {
          // 2. EMIT SUBTITLE IMMEDIATELY
          io.to(rSocketId).emit('receive_subtitle', {
            from: userId,
            text: translated || text.trim(),
            originalText: text.trim(),
            originalLanguage: detectedSource,
            targetLanguage: rLang,
            latencyMs
          });

          // 3. SYNTHESIZE SPEECH IN BACKGROUND
          if (shouldSpeak && isFinal && translated) {
            aiTranslationService.textToSpeech(translated, rLang)
              .then(audio => {
                if (audio) {
                  io.to(rSocketId).emit('receive_translated_audio', {
                    from: userId,
                    audioData: Array.from(audio),
                    language: rLang
                  });
                }
              });
          }
        }
        socket.emit('call_text_sent', { originalText: text.trim(), translatedText: translated, latencyMs, isFinal });
      } catch (e) { console.error('Call text error:', e); }
    });

    socket.on('webrtc_offer', (data) => {
      const target = activeUsers.get(data.to);
      if (target) io.to(target).emit('webrtc_offer', { from: socketToUser.get(socket.id), offer: data.offer, callType: data.callType });
    });

    socket.on('webrtc_answer', (data) => {
      const target = activeUsers.get(data.to);
      if (target) io.to(target).emit('webrtc_answer', { from: socketToUser.get(socket.id), answer: data.answer });
    });

    socket.on('webrtc_ice_candidate', (data) => {
      const target = activeUsers.get(data.to);
      if (target) io.to(target).emit('webrtc_ice_candidate', { from: socketToUser.get(socket.id), candidate: data.candidate });
    });

    socket.on('disconnect', () => {
      const userId = socketToUser.get(socket.id);
      if (userId) {
        activeUsers.delete(userId);
        socketToUser.delete(socket.id);
        aiTranslationService.stopStream(userId);
        socket.broadcast.emit('user_offline', { userId });
      }
    });
  });
};

module.exports = { initializeSocket };
