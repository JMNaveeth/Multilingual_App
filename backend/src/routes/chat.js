const express = require('express');
const {
  sendMessage,
  getConversation,
  markAsRead,
  getConversationsList,
  deleteMessage
} = require('../controllers/chatController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// All chat routes require authentication
router.use(authenticate);

// Send a message
router.post('/messages', sendMessage);

// Get conversations list
router.get('/conversations', getConversationsList);

// Get conversation with a specific user
router.get('/conversations/:userId', getConversation);

// Mark messages as read
router.put('/conversations/:userId/read', markAsRead);

// Delete a message
router.delete('/messages/:messageId', deleteMessage);

module.exports = router;
