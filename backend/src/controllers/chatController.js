const Message = require('../models/Message');
const User = require('../models/User');

// @desc    Send a message
// @route   POST /api/chat/messages
// @access  Private
const sendMessage = async (req, res, next) => {
  try {
    const { receiverId, content, type = 'text', mediaUrl, metadata } = req.body;

    // Validation
    if (!receiverId || !content) {
      return res.status(400).json({
        success: false,
        message: 'Receiver ID and content are required'
      });
    }

    // Check if receiver exists
    const receiver = await User.findById(receiverId);
    if (!receiver) {
      return res.status(404).json({
        success: false,
        message: 'Receiver not found'
      });
    }

    // Create message
    const message = await Message.create({
      sender: req.user._id,
      receiver: receiverId,
      content: content.trim(),
      type,
      mediaUrl,
      metadata: metadata || {}
    });

    // Populate sender and receiver data
    await message.populate('sender', 'name email profileImageUrl isOnline');
    await message.populate('receiver', 'name email profileImageUrl isOnline');

    res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: {
        message
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Get conversation with a user
// @route   GET /api/chat/conversations/:userId
// @access  Private
const getConversation = async (req, res, next) => {
  try {
    const { userId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    // Check if user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Get messages
    const messages = await Message.getConversation(req.user._id, userId, limit, skip);

    // Mark messages as delivered (from the other user to current user)
    await Message.markAsDelivered(userId, req.user._id);

    // Get total count for pagination
    const totalMessages = await Message.countDocuments({
      $or: [
        { sender: req.user._id, receiver: userId },
        { sender: userId, receiver: req.user._id }
      ]
    });

    res.status(200).json({
      success: true,
      data: {
        messages,
        pagination: {
          page,
          limit,
          total: totalMessages,
          pages: Math.ceil(totalMessages / limit)
        },
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          profileImageUrl: user.profileImageUrl,
          isOnline: user.isOnline,
          preferredLanguage: user.preferredLanguage,
          lastSeen: user.lastSeen
        }
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Mark messages as read
// @route   PUT /api/chat/conversations/:userId/read
// @access  Private
const markAsRead = async (req, res, next) => {
  try {
    const { userId } = req.params;

    // Check if user exists
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Mark messages as read
    const result = await Message.markAsRead(userId, req.user._id);

    res.status(200).json({
      success: true,
      message: 'Messages marked as read',
      data: {
        modifiedCount: result.modifiedCount
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Get user's conversations list
// @route   GET /api/chat/conversations
// @access  Private
const getConversationsList = async (req, res, next) => {
  try {
    // Get all users the current user has chatted with
    const conversations = await Message.aggregate([
      {
        $match: {
          $or: [
            { sender: req.user._id },
            { receiver: req.user._id }
          ]
        }
      },
      {
        $sort: { createdAt: -1 }
      },
      {
        $group: {
          _id: {
            $cond: {
              if: { $eq: ['$sender', req.user._id] },
              then: '$receiver',
              else: '$sender'
            }
          },
          lastMessage: { $first: '$$ROOT' },
          unreadCount: {
            $sum: {
              $cond: [
                {
                  $and: [
                    { $eq: ['$receiver', req.user._id] },
                    { $ne: ['$status', 'read'] }
                  ]
                },
                1,
                0
              ]
            }
          }
        }
      },
      {
        $lookup: {
          from: 'users',
          localField: '_id',
          foreignField: '_id',
          as: 'user'
        }
      },
      {
        $unwind: '$user'
      },
      {
        $project: {
          _id: 0,
          user: {
            id: '$user._id',
            name: '$user.name',
            email: '$user.email',
            profileImageUrl: '$user.profileImageUrl',
            isOnline: '$user.isOnline',
            preferredLanguage: '$user.preferredLanguage',
            lastSeen: '$user.lastSeen'
          },
          lastMessage: {
            id: '$lastMessage._id',
            content: '$lastMessage.content',
            type: '$lastMessage.type',
            status: '$lastMessage.status',
            createdAt: '$lastMessage.createdAt'
          },
          unreadCount: 1
        }
      }
    ]);

    res.status(200).json({
      success: true,
      data: {
        conversations
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Delete a message
// @route   DELETE /api/chat/messages/:messageId
// @access  Private
const deleteMessage = async (req, res, next) => {
  try {
    const { messageId } = req.params;

    const message = await Message.findById(messageId);

    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message not found'
      });
    }

    // Check if user owns the message
    if (message.sender.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this message'
      });
    }

    await Message.findByIdAndDelete(messageId);

    res.status(200).json({
      success: true,
      message: 'Message deleted successfully'
    });

  } catch (error) {
    next(error);
  }
};

module.exports = {
  sendMessage,
  getConversation,
  markAsRead,
  getConversationsList,
  deleteMessage
};

