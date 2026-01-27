const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Sender is required']
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  receiver: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: [true, 'Receiver is required']
  },
  receiverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  content: {
    type: String,
    required: [true, 'Message content is required'],
    trim: true,
    maxlength: [1000, 'Message cannot be more than 1000 characters']
  },
  type: {
    type: String,
    enum: {
      values: ['text', 'image', 'audio', 'video'],
      message: 'Please select a valid message type'
    },
    default: 'text'
  },
  status: {
    type: String,
    enum: {
      values: ['sent', 'delivered', 'read'],
      message: 'Please select a valid message status'
    },
    default: 'sent'
  },
  isRead: {
    type: Boolean,
    default: false
  },
  mediaUrl: {
    type: String,
    default: null
  },
  metadata: {
    type: mongoose.Schema.Types.Mixed,
    default: {}
  },
  // For future features like message threads, replies, etc.
  replyTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null
  },
  // For group chats (future enhancement)
  conversationId: {
    type: String,
    default: null
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

// Indexes for better query performance
messageSchema.index({ sender: 1, receiver: 1 });
messageSchema.index({ receiver: 1, sender: 1 });
messageSchema.index({ senderId: 1, receiverId: 1 });
messageSchema.index({ receiverId: 1, senderId: 1 });
messageSchema.index({ createdAt: -1 });
messageSchema.index({ conversationId: 1 });
messageSchema.index({ isRead: 1 });

// Pre-save middleware to sync sender/receiver with senderId/receiverId
messageSchema.pre('save', function(next) {
  if (this.sender && !this.senderId) {
    this.senderId = this.sender;
  }
  if (this.receiver && !this.receiverId) {
    this.receiverId = this.receiver;
  }
  if (this.status === 'read') {
    this.isRead = true;
  }
  next();
});

// Virtual for conversation key (to group messages between two users)
messageSchema.virtual('conversationKey').get(function() {
  const ids = [this.sender.toString(), this.receiver.toString()].sort();
  return ids.join('_');
});

// Static method to get conversation between two users
messageSchema.statics.getConversation = function(userId1, userId2, limit = 50, skip = 0) {
  return this.find({
    $or: [
      { sender: userId1, receiver: userId2 },
      { sender: userId2, receiver: userId1 }
    ]
  })
  .populate('sender', 'name email profileImageUrl isOnline')
  .populate('receiver', 'name email profileImageUrl isOnline')
  .sort({ createdAt: -1 })
  .limit(limit)
  .skip(skip);
};

// Static method to mark messages as read
messageSchema.statics.markAsRead = function(senderId, receiverId) {
  return this.updateMany(
    { sender: senderId, receiver: receiverId, status: { $ne: 'read' } },
    { status: 'read' }
  );
};

// Static method to mark messages as delivered
messageSchema.statics.markAsDelivered = function(senderId, receiverId) {
  return this.updateMany(
    { sender: senderId, receiver: receiverId, status: 'sent' },
    { status: 'delivered' }
  );
};

// Instance method to check if message is from specific user
messageSchema.methods.isFrom = function(userId) {
  return this.sender.toString() === userId.toString();
};

module.exports = mongoose.model('Message', messageSchema);

