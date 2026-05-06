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
    if (!text || text.trim() === '') return { text: null, detected: null };
    const targetLang = to || 'en';
    const sourceLang = from || 'auto';
    
    if (sourceLang !== 'auto' && sourceLang === targetLang) {
      return { text: null, detected: sourceLang };
    }

    const normalizedText = text.trim();
    const cacheKey = `${sourceLang}:${targetLang}:${normalizedText}`;
    const cached = this._getFromCache(this.translationCache, cacheKey);
    if (cached) return cached;

    try {
      const result = await translate(normalizedText, { 
        from: sourceLang === 'auto' ? undefined : sourceLang, 
        to: targetLang 
      });

      if (result.text.toLowerCase() === normalizedText.toLowerCase()) {
        return { text: null, detected: result.from.language.iso };
      }

      const response = { text: result.text, detected: result.from.language.iso };
      this._setCache(this.translationCache, cacheKey, response);
      return response;
    } catch (error) {
      console.error('Translation error:', error.message);
      return { text: null, detected: null };
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
   * Placeholder for future streaming speech-to-text.
   * Currently logs incoming chunks for debugging; ready for STT integration.
   */
  processAudioChunk(userId, audioData) {
    const stream = this.activeStreams.get(userId);
    if (!stream || !audioData) {
      return;
    }
    // Future: pipe audioData to a streaming STT service (e.g., Google Cloud Speech)
    // and call processCallText() with the transcription result.
    // For now, on-device STT handles this via the send_call_text event.
  }

  /**
   * Process a text message during a call and send translated text + audio to the peer.
   * Includes latency measurement for monitoring sub-2-second target.
   */
  async processCallText(userId, text) {
    if (!text || text.trim() === '') return;

    const stream = this.activeStreams.get(userId);
    if (!stream) return;

    const startMs = Date.now();

    try {
      // 1. FAST TEXT TRANSLATION ONLY
      const result = await this.translateText(
        text.trim(),
        stream.sourceLanguage,
        stream.targetLanguage
      );
      const translatedText = result.text;
      const detectedSource = result.detected || stream.sourceLanguage;

      const latencyMs = Date.now() - startMs;
      const targetSocketId = stream.activeUsers.get(stream.targetUserId);

      if (targetSocketId) {
        // 2. EMIT SUBTITLE IMMEDIATELY
        stream.io.to(targetSocketId).emit('receive_subtitle', {
          from: userId,
          text: translatedText || text.trim(),
          originalText: text,
          originalLanguage: detectedSource,
          targetLanguage: stream.targetLanguage,
          latencyMs
        });

        // 3. SYNTHESIZE SPEECH ASYNCHRONOUSLY
        if (translatedText) {
          this.textToSpeech(translatedText, stream.targetLanguage)
          .then(audioBuffer => {
            if (audioBuffer && targetSocketId) {
              stream.io.to(targetSocketId).emit('receive_translated_audio', {
                from: userId,
                audioData: Array.from(audioBuffer),
                language: stream.targetLanguage,
                latencyMs: Date.now() - startMs
              });
            }
          })
          .catch(err => console.error('TTS Background error:', err.message));
      }

      // Log latency for monitoring
      const emoji = latencyMs < 1500 ? '⚡' : latencyMs < 2500 ? '🟡' : '🔴';
      console.log(`${emoji} Stream pipeline: ${latencyMs}ms (${stream.sourceLanguage}→${stream.targetLanguage})`);

      return { latencyMs };
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
