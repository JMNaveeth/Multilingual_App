const path = require('path');
const fs = require('fs');

const historyFilePath = path.resolve(__dirname, '../../data/chat_history.json');

/** Ensure the history file exists */
function ensureHistoryFile() {
  if (!fs.existsSync(historyFilePath)) {
    fs.mkdirSync(path.dirname(historyFilePath), { recursive: true });
    fs.writeFileSync(historyFilePath, JSON.stringify([]), 'utf8');
  }
}

/** Load chat history array */
function loadHistory() {
  ensureHistoryFile();
  const raw = fs.readFileSync(historyFilePath, 'utf8');
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/** Append a message object to history and write back */
function appendMessageToHistory(message) {
  const history = loadHistory();
  history.push(message);
  fs.writeFileSync(historyFilePath, JSON.stringify(history, null, 2), 'utf8');
}

module.exports = { loadHistory, appendMessageToHistory };
