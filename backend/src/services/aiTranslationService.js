

class AITranslationService {
  constructor() {
    this.activeStreams = new Map(); // userId -> { targetUserId, targetLanguage, sourceLanguage, io, activeUsers }
    this.translationCache = new Map(); // key -> { value, expiresAt }
    this.audioCache = new Map(); // key -> { value, expiresAt }
    this.cacheTtlMs = 60 * 1000;
    this.maxCacheEntries = 200;
    this.libreTranslateUrl = process.env.LIBRE_TRANSLATE_URL || 'https://libretranslate.com';
  }

  /**
   * Helper to perform HTTP POST to LibreTranslate.
   */
  async _postLibreTranslate(path, body) {
    const url = `${this.libreTranslateUrl}${path}`;
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`LibreTranslate error ${response.status}: ${text}`);
    }
    return response.json();
  }

  /**
   * Translate text from one language to another using LibreTranslate.
   * @param {string} text - The text to translate
   * @param {string|null} from - Source language code (null for auto-detect)
   * @param {string} to - Target language code
   * @returns {Promise<{text: string|null, detected: string|null}>}
   */
  async translateText(text, from, to) {
    if (!text || text.trim() === '') return { text: null, detected: null };
    const targetLang = to || 'en';
    const sourceLang = from || 'auto';

    // Avoid unnecessary translation if source and target are same (except when auto)
    if (sourceLang !== 'auto' && sourceLang === targetLang) {
      return { text: null, detected: sourceLang };
    }

    const normalizedText = text.trim();
    const cacheKey = `${sourceLang}:${targetLang}:${normalizedText}`;
    const cached = this._getFromCache(this.translationCache, cacheKey);
    if (cached) return cached;

    try {
      const payload = {
        q: normalizedText,
        source: sourceLang === 'auto' ? 'auto' : sourceLang,
        target: targetLang,
        format: 'text',
        api_key: '' // public instance does not require a key
      };
      const result = await this._postLibreTranslate('/translate', payload);
      // LibreTranslate returns { translatedText: '...' }
      const translated = result.translatedText || null;

      // Detect language if source was auto
      let detected = null;
      if (sourceLang === 'auto') {
        const detectRes = await this._postLibreTranslate('/detect', { q: normalizedText });
        if (Array.isArray(detectRes) && detectRes.length > 0) {
          detected = detectRes[0].language;
        }
      } else {
        detected = sourceLang;
      }

      const response = { text: translated, detected };
      this._setCache(this.translationCache, cacheKey, response);
      return response;
    } catch (error) {
      console.error('LibreTranslate error:', error.message);
      return { text: null, detected: null };
    }
  }

  /**
   * Convert text to speech audio buffer using Google TTS (kept unchanged).
   */
  async textToSpeech(text, lang) {
    // Existing implementation retained (uses gtts)
    if (!text || text.trim() === '') return null;
    const normalizedText = text.trim();
    const cacheKey = `${lang}:${normalizedText}`;
    const cached = this._getFromCache(this.audioCache, cacheKey);
    if (cached) {
      return cached;
    }

    return new Promise((resolve, reject) => {
      try {
        const gtts = require('gtts');
        const ttsInstance = new gtts(normalizedText, lang);
        const chunks = [];
        const { PassThrough } = require('stream');
        const passThrough = new PassThrough();
        ttsInstance.stream().pipe(passThrough);
        passThrough.on('data', chunk => chunks.push(chunk));
        passThrough.on('end', () => {
          const audioBuffer = Buffer.concat(chunks);
          this._setCache(this.audioCache, cacheKey, audioBuffer);
          console.log(`🔊 TTS generated: ${audioBuffer.length} bytes (${lang})`);
          resolve(audioBuffer);
        });
        passThrough.on('error', err => {
          console.error('TTS stream error:', err);
          reject(err);
        });
      } catch (error) {
        console.error('TTS error:', error);
        reject(error);
      }
    });
  }

  /**
   * Full pipeline: translate + TTS.
   */
  async translateAndSpeak(text, sourceLanguage, targetLanguage) {
    const translated = await this.translateText(text, sourceLanguage, targetLanguage);
    let audioBuffer = null;
    if (translated.text) {
      try {
        audioBuffer = await this.textToSpeech(translated.text, targetLanguage);
      } catch (err) {
        console.error('TTS failed, sending text only:', err.message);
      }
    }
    return { translatedText: translated, audioBuffer };
  }

  // Stream management methods (unchanged logic, just rely on translateText)
  startStream(userId, targetUserId, sourceLanguage, targetLanguage, io, socketToUser, activeUsers) {
    console.log(`🎙️ Starting translation stream: ${userId} → ${targetUserId} (${sourceLanguage}→${targetLanguage})`);
    this.activeStreams.set(userId, { targetUserId, sourceLanguage, targetLanguage, io, activeUsers });
  }

  processAudioChunk(userId, audioData) {
    const stream = this.activeStreams.get(userId);
    if (!stream || !audioData) return;
    // Future STT integration placeholder
  }

  async processCallText(userId, text) {
    if (!text || text.trim() === '') return;
    const stream = this.activeStreams.get(userId);
    if (!stream) return;
    const startMs = Date.now();
    try {
      const result = await this.translateText(text.trim(), stream.sourceLanguage, stream.targetLanguage);
      const translatedText = result.text;
      const detectedSource = result.detected || stream.sourceLanguage;
      const latencyMs = Date.now() - startMs;
      const targetSocketId = stream.activeUsers.get(stream.targetUserId);
      if (targetSocketId) {
        // Emit subtitle immediately
        stream.io.to(targetSocketId).emit('receive_subtitle', {
          from: userId,
          text: translatedText || text.trim(),
          originalText: text.trim(),
          originalLanguage: detectedSource,
          targetLanguage: stream.targetLanguage,
          latencyMs,
        });
        // Synthesize speech asynchronously
        if (translatedText) {
          this.textToSpeech(translatedText, stream.targetLanguage)
            .then(audio => {
              if (audio) {
                stream.io.to(targetSocketId).emit('receive_translated_audio', {
                  from: userId,
                  audioData: Array.from(audio),
                  language: stream.targetLanguage,
                  latencyMs: Date.now() - startMs,
                });
              }
            })
            .catch(err => console.error('TTS Background error:', err.message));
        }
      }
      const emoji = latencyMs < 1500 ? '⚡' : latencyMs < 2500 ? '🟡' : '🔴';
      console.log(`${emoji} Stream pipeline: ${latencyMs}ms (${stream.sourceLanguage}→${stream.targetLanguage})`);
      return { latencyMs };
    } catch (error) {
      console.error('processCallText error:', error);
    }
  }

  stopStream(userId) {
    const stream = this.activeStreams.get(userId);
    if (stream) {
      this.activeStreams.delete(userId);
      console.log(`🛑 Translation stream stopped for ${userId}`);
    }
  }

  _getFromCache(store, key) {
    const entry = store.get(key);
    if (!entry) return null;
    if (Date.now() > entry.expiresAt) {
      store.delete(key);
      return null;
    }
    return entry.value;
  }

  _setCache(store, key, value) {
    if (!value) return;
    store.set(key, { value, expiresAt: Date.now() + this.cacheTtlMs });
    if (store.size > this.maxCacheEntries) {
      const oldestKey = store.keys().next().value;
      if (oldestKey) store.delete(oldestKey);
    }
  }
}

module.exports = new AITranslationService();

