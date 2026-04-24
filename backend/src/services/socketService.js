const User = require('../models/User');
const Message = require('../models/Message');
const aiTranslationService = require('./aiTranslationService');

// Store active users and their socket connections
const activeUsers = new Map(); // userId -> socketId
const socketToUser = new Map(); // socketId -> userId

const initializeSocket = (io) => {
  io.on('connection', (socket) => {
    console.log(`🔌 New socket connection: ${socket.id}`);

    // User authentication
    socket.on('authenticate', async (data) => {
      try {
        const { token } = data;

        if (!token) {
          socket.emit('unauthenticated', { message: 'Token required' });
          return;
        }

        // Here you would verify the JWT token
        // For now, we'll assume the token contains the user ID
        const userId = token; // In real implementation, decode JWT

        const user = await User.findById(userId);
        if (!user) {
          socket.emit('unauthenticated', { message: 'User not found' });
          return;
        }

        // Store user connection
        activeUsers.set(userId, socket.id);
        socketToUser.set(socket.id, userId);

        // Join user to their own room
        socket.join(userId);

        // Update user online status
        user.isOnline = true;
        user.socketId = socket.id;
        user.lastSeen = new Date();
        await user.save();

        socket.emit('authenticated', {
          user: user.toPublicProfile(),
          message: 'Authentication successful'
        });

        // Notify friends about online status
        socket.broadcast.emit('user_online', {
          userId,
          user: user.toPublicProfile()
        });

        console.log(`✅ User ${user.name} authenticated: ${socket.id}`);

      } catch (error) {
        console.error('Authentication error:', error);
        socket.emit('unauthenticated', { message: 'Authentication failed' });
      }
    });

    // Handle private messaging
    socket.on('send_message', async (data) => {
      try {
        const { receiverId, content, type = 'text', mediaUrl, metadata } = data;
        const senderId = socketToUser.get(socket.id);

        if (!senderId) {
          socket.emit('error', { message: 'Not authenticated' });
          return;
        }

        // Create and save message
        const message = await Message.create({
          sender: senderId,
          receiver: receiverId,
          content: content.trim(),
          type,
          mediaUrl,
          metadata: metadata || {}
        });

        // Populate message data
        await message.populate('sender', 'name email profileImageUrl isOnline');
        await message.populate('receiver', 'name email profileImageUrl isOnline');

        const messageData = {
          id: message._id,
          sender: message.sender,
          receiver: message.receiver,
          content: message.content,
          type: message.type,
          status: message.status,
          mediaUrl: message.mediaUrl,
          metadata: message.metadata,
          createdAt: message.createdAt
        };

        // Send to receiver if online
        const receiverSocketId = activeUsers.get(receiverId);
        if (receiverSocketId) {
          io.to(receiverSocketId).emit('new_message', messageData);
        }

        // Send confirmation to sender
        socket.emit('message_sent', messageData);

        console.log(`📨 Message sent from ${senderId} to ${receiverId}`);

      } catch (error) {
        console.error('Send message error:', error);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // Mark messages as read
    socket.on('mark_read', async (data) => {
      try {
        const { senderId } = data;
        const userId = socketToUser.get(socket.id);

        if (!userId) {
          socket.emit('error', { message: 'Not authenticated' });
          return;
        }

        await Message.markAsRead(senderId, userId);

        // Notify sender that messages were read
        const senderSocketId = activeUsers.get(senderId);
        if (senderSocketId) {
          io.to(senderSocketId).emit('messages_read', {
            readerId: userId,
            timestamp: new Date()
          });
        }

      } catch (error) {
        console.error('Mark read error:', error);
        socket.emit('error', { message: 'Failed to mark messages as read' });
      }
    });

    // WebRTC Signaling for video calls
    socket.on('call_user', (data) => {
      const { userToCall, signalData, from, name } = data;
      const receiverSocketId = activeUsers.get(userToCall);

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('call_user', {
          signal: signalData,
          from,
          name
        });
      }
    });

    socket.on('answer_call', (data) => {
      const { to, signal } = data;
      const receiverSocketId = activeUsers.get(to);

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('call_accepted', signal);
      }
    });

    socket.on('end_call', (data) => {
      const { to } = data;
      const receiverSocketId = activeUsers.get(to);
      const userId = socketToUser.get(socket.id);

      // Clean up any active translation streams
      if (userId) {
        aiTranslationService.stopStream(userId);
      }
      if (to) {
        aiTranslationService.stopStream(to);
      }

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('call_ended');
      }
    });

    socket.on('webrtc_offer', (data) => {
      const { to, offer, callType } = data;
      const from = socketToUser.get(socket.id);
      const receiverSocketId = activeUsers.get(to);

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('webrtc_offer', {
          from,
          offer,
          callType
        });
      }
    });

    socket.on('webrtc_answer', (data) => {
      const { to, answer, callType } = data;
      const from = socketToUser.get(socket.id);
      const receiverSocketId = activeUsers.get(to);

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('webrtc_answer', {
          from,
          answer,
          callType
        });
      }
    });

    socket.on('webrtc_ice_candidate', (data) => {
      const { to, candidate } = data;
      const from = socketToUser.get(socket.id);
      const receiverSocketId = activeUsers.get(to);

      if (receiverSocketId) {
        io.to(receiverSocketId).emit('webrtc_ice_candidate', {
          from,
          candidate
        });
      }
    });

    // AI Translation signaling & Audio Streaming Hook
    socket.on('start_translation', (data) => {
      const { targetUserId, sourceLanguage, targetLanguage } = data;
      const userId = socketToUser.get(socket.id);

      if (!userId) return;

      // Start the translation pipeline in the backend
      aiTranslationService.startStream(
        userId, 
        targetUserId, 
        sourceLanguage, 
        targetLanguage, 
        io, 
        socketToUser, 
        activeUsers
      );

      const targetSocketId = activeUsers.get(targetUserId);
      if (targetSocketId) {
        io.to(targetSocketId).emit('translation_started', {
          from: userId,
          language: targetLanguage
        });
      }
    });

    socket.on('translation_audio', (data) => {
      const { targetUserId, audioData } = data;
      const userId = socketToUser.get(socket.id);

      if (!userId) return;

      // Pipe the audio chunk into the translation service instead of relaying it directly
      aiTranslationService.processAudioChunk(userId, audioData);
    });

    socket.on('translated_text', (data) => {
      const { targetUserId, text, originalLanguage, targetLanguage } = data;
      const userId = socketToUser.get(socket.id);

      if (!userId) return;

      const targetSocketId = activeUsers.get(targetUserId);
      if (targetSocketId) {
        io.to(targetSocketId).emit('receive_subtitle', {
          from: userId,
          text,
          originalLanguage,
          targetLanguage
        });
      }
    });

    socket.on('translated_audio', (data) => {
      const { targetUserId, audioData, language } = data;
      const userId = socketToUser.get(socket.id);

      if (!userId) return;

      const targetSocketId = activeUsers.get(targetUserId);
      if (targetSocketId) {
        io.to(targetSocketId).emit('receive_translated_audio', {
          from: userId,
          audioData,
          language
        });
      }
    });

    // Handle typing indicators
    socket.on('typing_start', (data) => {
      const { receiverId } = data;
      const userId = socketToUser.get(socket.id);

      if (!userId) return;

      const receiverSocketId = activeUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('user_typing', {
          userId,
          isTyping: true
        });
      }
    });

    socket.on('typing_stop', (data) => {
      const { receiverId } = data;
      const userId = socketToUser.get(socket.id);

      if (!userId) return;

      const receiverSocketId = activeUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('user_typing', {
          userId,
          isTyping: false
        });
      }
    });

    // Handle disconnection
    socket.on('disconnect', async () => {
      console.log(`🔌 Socket disconnected: ${socket.id}`);

      const userId = socketToUser.get(socket.id);
      if (userId) {
        // Clean up translation streams
        aiTranslationService.stopStream(userId);

        // Remove from active users
        activeUsers.delete(userId);
        socketToUser.delete(socket.id);

        // Update user offline status
        try {
          const user = await User.findById(userId);
          if (user) {
            user.isOnline = false;
            user.lastSeen = new Date();
            user.socketId = null;
            await user.save();

            // Notify other users
            socket.broadcast.emit('user_offline', {
              userId,
              lastSeen: user.lastSeen
            });
          }
        } catch (error) {
          console.error('Error updating user offline status:', error);
        }
      }
    });

    // Handle manual logout
    socket.on('logout', async () => {
      const userId = socketToUser.get(socket.id);
      if (userId) {
        activeUsers.delete(userId);
        socketToUser.delete(socket.id);

        try {
          const user = await User.findById(userId);
          if (user) {
            user.isOnline = false;
            user.lastSeen = new Date();
            user.socketId = null;
            await user.save();
          }
        } catch (error) {
          console.error('Error during logout:', error);
        }
      }

      socket.disconnect();
    });
  });
};

module.exports = {
  initializeSocket,
  activeUsers,
  socketToUser
};

