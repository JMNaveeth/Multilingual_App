const supabase = require('../config/supabase');
const { appendMessageToHistory, loadHistory } = require('../services/chatPersistence');

// @desc    Send a message
// @route   POST /api/chat/messages
// @access  Private
const sendMessage = async (req, res, next) => {
  try {
    const { receiverId, content, type = 'text', metadata } = req.body;

    if (!receiverId || !content) {
      return res.status(400).json({ success: false, message: 'Receiver ID and content are required' });
    }

    const { data: message, error } = await supabase
      .from('messages')
      .insert({
        sender_id: req.user.id,
        receiver_id: receiverId,
        content: content.trim(),
        type,
        metadata: metadata || {}
      })
      .select()
      .single();

    await appendMessageToHistory(message);


    res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: { message }
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
    const limit = parseInt(req.query.limit) || 50;

    const { data: messages, error } = await supabase
      .from('messages')
      .select('*')
      .or(`and(sender_id.eq.${req.user.id},receiver_id.eq.${userId}),and(sender_id.eq.${userId},receiver_id.eq.${req.user.id})`)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) throw error;

    res.status(200).json({
      success: true,
      data: { messages: messages.reverse() }
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

    const { error } = await supabase
      .from('messages')
      .update({ status: 'read' })
      .eq('sender_id', userId)
      .eq('receiver_id', req.user.id)
      .neq('status', 'read');

    if (error) throw error;

    res.status(200).json({ success: true, message: 'Messages marked as read' });
  } catch (error) {
    next(error);
  }
};

// @desc    Get user's conversations list
// @route   GET /api/chat/conversations
// @access  Private
const getConversationsList = async (req, res, next) => {
  try {
    // Note: Supabase/Postgres logic for grouping conversations is different from MongoDB
    // This is a simplified version; in production, you might use a dedicated RPC or view
    const { data: messages, error } = await supabase
      .from('messages')
      .select('*, sender_id, receiver_id')
      .or(`sender_id.eq.${req.user.id},receiver_id.eq.${req.user.id}`)
      .order('created_at', { ascending: false });

    if (error) throw error;

    // Logic to group by conversation partner
    const conversationsMap = new Map();
    messages.forEach(msg => {
      const partnerId = msg.sender_id === req.user.id ? msg.receiver_id : msg.sender_id;
      if (!conversationsMap.has(partnerId)) {
        conversationsMap.set(partnerId, {
          partnerId,
          lastMessage: msg,
          unreadCount: (msg.receiver_id === req.user.id && msg.status !== 'read') ? 1 : 0
        });
      } else if (msg.receiver_id === req.user.id && msg.status !== 'read') {
        conversationsMap.get(partnerId).unreadCount++;
      }
    });

    res.status(200).json({
      success: true,
      data: { conversations: Array.from(conversationsMap.values()) }
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

    const { error } = await supabase
      .from('messages')
      .delete()
      .eq('id', messageId)
      .eq('sender_id', req.user.id);

    if (error) throw error;

    res.status(200).json({ success: true, message: 'Message deleted successfully' });
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
