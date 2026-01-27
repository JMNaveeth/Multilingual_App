const express = require('express');
const router = express.Router();
const User = require('../models/User');
const Message = require('../models/Message');
const Group = require('../models/Group');

// Get app-wide statistics
router.get('/stats', async (req, res) => {
  try {
    // Count active users (logged in within last 15 minutes)
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
    const activeUsers = await User.countDocuments({
      lastActive: { $gte: fifteenMinutesAgo },
      isOnline: true
    });

    // Count total messages
    const totalMessages = await Message.countDocuments();

    // Count total groups
    const totalGroups = await Group.countDocuments();

    res.json({
      activeUsers,
      totalMessages,
      totalGroups,
      lastUpdated: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ 
      message: 'Error fetching statistics',
      error: error.message 
    });
  }
});

// Get user-specific statistics
router.get('/users/:userId/stats', async (req, res) => {
  try {
    const { userId } = req.params;

    // Count user's messages
    const totalMessages = await Message.countDocuments({
      $or: [
        { senderId: userId },
        { receiverId: userId }
      ]
    });

    // Count user's groups
    const totalGroups = await Group.countDocuments({
      members: userId
    });

    // Count unread messages
    const unreadMessages = await Message.countDocuments({
      receiverId: userId,
      isRead: false
    });

    // Count contacts with recent activity
    const activeContacts = await Message.distinct('senderId', {
      receiverId: userId,
      createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) }
    });

    res.json({
      activeUsers: activeContacts.length,
      totalMessages,
      totalGroups,
      unreadMessages,
      lastUpdated: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching user stats:', error);
    res.status(500).json({ 
      message: 'Error fetching user statistics',
      error: error.message 
    });
  }
});

// Get real-time activity feed
router.get('/activity', async (req, res) => {
  try {
    const recentMessages = await Message.find()
      .sort({ createdAt: -1 })
      .limit(10)
      .populate('senderId', 'name avatar')
      .populate('receiverId', 'name avatar');

    const recentGroups = await Group.find()
      .sort({ lastActivity: -1 })
      .limit(5)
      .populate('members', 'name avatar');

    res.json({
      recentMessages,
      recentGroups,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error fetching activity:', error);
    res.status(500).json({ 
      message: 'Error fetching activity feed',
      error: error.message 
    });
  }
});

module.exports = router;
