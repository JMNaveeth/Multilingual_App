const jwt = require('jsonwebtoken');
const supabase = require('../config/supabase');

// Middleware to verify JWT token
const authenticate = async (req, res, next) => {
  try {
    let token;

    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.'
      });
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
      
      // Get user from Supabase profiles instead of MongoDB
      const { data: user, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', decoded.id)
        .single();

      if (error || !user) {
        // Fallback for dev: if decoding succeeded but user not in profiles, 
        // we might be using raw IDs or the user hasn't created a profile yet
        req.user = { id: decoded.id };
        return next();
      }

      req.user = user;
      next();

    } catch (tokenError) {
      return res.status(401).json({
        success: false,
        message: 'Invalid token.'
      });
    }

  } catch (error) {
    console.error('Authentication middleware error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error during authentication.'
    });
  }
};

const optionalAuth = async (req, res, next) => {
  try {
    let token;
    if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
      token = req.headers.authorization.split(' ')[1];
    }
    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
        const { data: user } = await supabase.from('profiles').select('*').eq('id', decoded.id).single();
        if (user) req.user = user;
        else req.user = { id: decoded.id };
      } catch (e) {}
    }
    next();
  } catch (error) {
    next();
  }
};

const generateToken = (userId) => {
  return jwt.sign(
    { id: userId },
    process.env.JWT_SECRET || 'your-secret-key',
    { expiresIn: process.env.JWT_EXPIRE || '30d' }
  );
};

const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) return res.status(401).json({ success: false, message: 'Auth required' });
    next();
  };
};

module.exports = {
  authenticate,
  optionalAuth,
  generateToken,
  authorize
};
