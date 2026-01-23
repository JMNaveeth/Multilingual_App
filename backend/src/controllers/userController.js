const User = require('../models/User');

// @desc    Get all users (for contact list)
// @route   GET /api/users
// @access  Private
const getUsers = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;
    const search = req.query.search || '';
    const language = req.query.language;

    // Build query
    let query = {
      _id: { $ne: req.user._id } // Exclude current user
    };

    // Add search filter
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } }
      ];
    }

    // Add language filter
    if (language) {
      query.preferredLanguage = language;
    }

    // Get users
    const users = await User.find(query)
      .select('name email profileImageUrl isOnline preferredLanguage lastSeen createdAt')
      .sort({ isOnline: -1, lastSeen: -1, name: 1 })
      .limit(limit)
      .skip(skip);

    // Get total count
    const total = await User.countDocuments(query);

    res.status(200).json({
      success: true,
      data: {
        users,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Get user by ID
// @route   GET /api/users/:id
// @access  Private
const getUserById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const user = await User.findById(id).select('-password');

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        user: user.toPublicProfile()
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Get users by language
// @route   GET /api/users/language/:language
// @access  Private
const getUsersByLanguage = async (req, res, next) => {
  try {
    const { language } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const users = await User.find({
      preferredLanguage: language,
      _id: { $ne: req.user._id }
    })
      .select('name email profileImageUrl isOnline preferredLanguage lastSeen createdAt')
      .sort({ isOnline: -1, lastSeen: -1, name: 1 })
      .limit(limit)
      .skip(skip);

    const total = await User.countDocuments({
      preferredLanguage: language,
      _id: { $ne: req.user._id }
    });

    res.status(200).json({
      success: true,
      data: {
        users,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Update user online status
// @route   PUT /api/users/status
// @access  Private
const updateOnlineStatus = async (req, res, next) => {
  try {
    const { isOnline, socketId } = req.body;

    const updateData = {
      isOnline: isOnline ?? true,
      lastSeen: new Date()
    };

    if (socketId !== undefined) {
      updateData.socketId = socketId;
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      updateData,
      { new: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        user: user.toPublicProfile()
      }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Get online users
// @route   GET /api/users/online
// @access  Private
const getOnlineUsers = async (req, res, next) => {
  try {
    const users = await User.find({
      isOnline: true,
      _id: { $ne: req.user._id }
    })
      .select('name email profileImageUrl isOnline preferredLanguage lastSeen')
      .sort({ lastSeen: -1 });

    res.status(200).json({
      success: true,
      data: {
        users,
        count: users.length
      }
    });

  } catch (error) {
    next(error);
  }
};

module.exports = {
  getUsers,
  getUserById,
  getUsersByLanguage,
  updateOnlineStatus,
  getOnlineUsers
};
