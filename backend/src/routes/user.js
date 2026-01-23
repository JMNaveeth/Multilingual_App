const express = require('express');
const {
  getUsers,
  getUserById,
  getUsersByLanguage,
  updateOnlineStatus,
  getOnlineUsers
} = require('../controllers/userController');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// All user routes require authentication
router.use(authenticate);

// Get all users (contact list)
router.get('/', getUsers);

// Get online users
router.get('/online', getOnlineUsers);

// Get user by ID
router.get('/:id', getUserById);

// Get users by language
router.get('/language/:language', getUsersByLanguage);

// Update online status
router.put('/status', updateOnlineStatus);

module.exports = router;
