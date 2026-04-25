const translate = require('google-translate-api-x');
const gtts = require('gtts');
const { PassThrough } = require('stream');

class AITranslationService {
  constructor() {
    this.activeStreams = new Map(); // userId -> { targetUserId, targetLanguage, sourceLanguage }
    this.translationCache = new Map(); // key -> { value, expiresAt }
    this.audioCache = new Map(); // key -> { value, expiresAt }
    this.cacheTtlMs = 60 * 1000;
    this.maxCacheEntries = 200;
  }

  /**
   * Translate text from one language to another using Google Translate.
   * @param {string} text - The text to translate
   * @param {string} from - Source language code (e.g., 'en')
   * @param {string} to - Target language code (e.g., 'ta')
   * @returns {Promise<string>} Translated text
   */
  async translateText(text, from, to) {
    if (!text || text.trim() === '') return text;
    if (from === to) return text;
    const normalizedText = text.trim();
    const cacheKey = `${from}:${to}:${normalizedText}`;
    const cached = this._getFromCache(this.translationCache, cacheKey);
    if (cached) {
      return cached;
    }

    try {
      const result = await translate(normalizedText, { from, to });
      this._setCache(this.translationCache, cacheKey, result.text);
      console.log(`🌐 Translated: "${normalizedText}" → "${result.text}" (${from}→${to})`);
      return result.text;
    } catch (error) {
      console.error('Translation error:', error.message);
      // Fallback: return original text if translation fails
      return normalizedText;
    }
  }

  /**
   * Convert text to speech audio buffer using Google TTS.
   * @param {string} text - Text to synthesize
   * @param {string} lang - Language code (e.g., 'ta', 'en')
   * @returns {Promise<Buffer>} Audio buffer (MP3)
   */
  async textToSpeech(text, lang) {
    if (!text || text.trim() === '') return null;
    const normalizedText = text.trim();
    const cacheKey = `${lang}:${normalizedText}`;
    const cached = this._getFromCache(this.audioCache, cacheKey);
    if (cached) {
      return cached;
    }

    return new Promise((resolve, reject) => {
      try {
        const ttsInstance = new gtts(normalizedText, lang);
        const chunks = [];
        const passThrough = new PassThrough();

        ttsInstance.stream().pipe(passThrough);

        passThrough.on('data', (chunk) => {
          chunks.push(chunk);
        });

        passThrough.on('end', () => {
          const audioBuffer = Buffer.concat(chunks);
          this._setCache(this.audioCache, cacheKey, audioBuffer);
          console.log(`🔊 TTS generated: ${audioBuffer.length} bytes (${lang})`);
          resolve(audioBuffer);
        });

        passThrough.on('error', (err) => {
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
   * Full pipeline: Translate text + generate TTS audio.
   * Returns both the translated text and the audio buffer.
   */
  async translateAndSpeak(text, sourceLanguage, targetLanguage) {
    // Step 1: Translate the text
    const translatedText = await this.translateText(text, sourceLanguage, targetLanguage);

    // Step 2: Convert translated text to speech
    let audioBuffer = null;
    try {
      audioBuffer = await this.textToSpeech(translatedText, targetLanguage);
    } catch (err) {
      console.error('TTS failed, sending text only:', err.message);
    }

    return { translatedText, audioBuffer };
  }

  /**
   * Starts a translation stream session for a call.
   */
  startStream(userId, targetUserId, sourceLanguage, targetLanguage, io, socketToUser, activeUsers) {
    console.log(`🎙️ Starting translation stream: ${userId} → ${targetUserId} (${sourceLanguage}→${targetLanguage})`);

    this.activeStreams.set(userId, {
      targetUserId,
      sourceLanguage,
      targetLanguage,
      io,
      activeUsers
    });
  }

  /**
   * Placeholder for future streaming speech translation.
   * Keeps the socket pipeline safe even if audio chunks are sent.
   */
  processAudioChunk(userId, audioData) {
    const stream = this.activeStreams.get(userId);
    if (!stream || !audioData) {
      return;
    }
    // Speech-to-text streaming is not wired yet. Intentionally no-op.
  }

  /**
   * Process a text message during a call and send translated text + audio to the peer.
   */
  async processCallText(userId, text) {
    if (!text || text.trim() === '') return;

    const stream = this.activeStreams.get(userId);
    if (!stream) return;

    try {
      const { translatedText, audioBuffer } = await this.translateAndSpeak(
        text,
        stream.sourceLanguage,
        stream.targetLanguage
      );

      const targetSockets = stream.activeUsers.get(stream.targetUserId);
      if (targetSockets && targetSockets.size > 0) {
        // Send translated subtitle text instantly
        stream.io.to(stream.targetUserId).emit('receive_subtitle', {
          from: userId,
          text: translatedText,
          originalText: text,
          originalLanguage: stream.sourceLanguage,
          targetLanguage: stream.targetLanguage
        });

        // Send TTS audio if available
        if (audioBuffer) {
          stream.io.to(stream.targetUserId).emit('receive_translated_audio', {
            from: userId,
            audioData: Array.from(audioBuffer), // Convert Buffer to array for Socket.io
            language: stream.targetLanguage
          });
        }
      }
    } catch (error) {
      console.error('processCallText error:', error);
    }
  }

  /**
   * Clean up resources when call ends or user disconnects.
   */
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
    store.set(key, {
      value,
      expiresAt: Date.now() + this.cacheTtlMs
    });
    if (store.size > this.maxCacheEntries) {
      const oldestKey = store.keys().next().value;
      if (oldestKey) {
        store.delete(oldestKey);
      }
    }
  }
}

module.exports = new AITranslationService();
