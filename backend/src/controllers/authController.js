const supabase = require('../config/supabase');
const { generateToken } = require('../middleware/auth');
const bcrypt = require('bcryptjs');

// @desc    Register user
// @route   POST /api/auth/register
const register = async (req, res, next) => {
  try {
    const { name, email, password, preferredLanguage } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Missing fields' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Check if user exists in profiles
    const { data: existingUser } = await supabase
      .from('profiles')
      .select('id')
      .eq('email', email.toLowerCase())
      .single();

    if (existingUser) {
      return res.status(400).json({ success: false, message: 'User already exists' });
    }

    // Insert into Supabase profiles
    const { data: user, error } = await supabase
      .from('profiles')
      .insert({
        name: name.trim(),
        email: email.toLowerCase().trim(),
        password: hashedPassword,
        preferred_language: preferredLanguage || 'en'
      })
      .select()
      .single();

    if (error) throw error;

    const token = generateToken(user.id);

    res.status(201).json({
      success: true,
      data: { user: { id: user.id, name: user.name, email: user.email, preferredLanguage: user.preferred_language }, token }
    });

  } catch (error) {
    next(error);
  }
};

// @desc    Login user
// @route   POST /api/auth/login
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ success: false, message: 'Missing fields' });

    const { data: user, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('email', email.toLowerCase())
      .single();

    if (error || !user) return res.status(401).json({ success: false, message: 'Invalid credentials' });

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ success: false, message: 'Invalid credentials' });

    // Update online status
    await supabase.from('profiles').update({ is_online: true, last_seen: new Date() }).eq('id', user.id);

    const token = generateToken(user.id);

    res.status(200).json({
      success: true,
      data: { user: { id: user.id, name: user.name, email: user.email, preferredLanguage: user.preferred_language }, token }
    });

  } catch (error) {
    next(error);
  }
};

const getMe = async (req, res, next) => {
  try {
    const { data: user, error } = await supabase.from('profiles').select('*').eq('id', req.user.id).single();
    if (error || !user) return res.status(404).json({ success: false, message: 'User not found' });

    res.status(200).json({ success: true, data: { user: { id: user.id, name: user.name, email: user.email, preferredLanguage: user.preferred_language } } });
  } catch (error) {
    next(error);
  }
};

const updateProfile = async (req, res, next) => {
  try {
    const { name, preferredLanguage, profileImageUrl } = req.body;
    const { data: user, error } = await supabase
      .from('profiles')
      .update({ name, preferred_language: preferredLanguage, profile_image_url: profileImageUrl })
      .eq('id', req.user.id)
      .select()
      .single();

    if (error) throw error;
    res.status(200).json({ success: true, data: { user } });
  } catch (error) {
    next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    await supabase.from('profiles').update({ is_online: false, last_seen: new Date() }).eq('id', req.user.id);
    res.status(200).json({ success: true, message: 'Logged out' });
  } catch (error) {
    next(error);
  }
};

module.exports = { register, login, getMe, updateProfile, logout };
