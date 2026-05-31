const { notifyFeedIngestion } = require('../utils/notifications');

let ingestionSocket = null;

function setIngestionSocket(io) {
  ingestionSocket = io;
}

async function emitFeedUpdated(payload) {
  if (ingestionSocket) {
    ingestionSocket.to('all').emit('feed_updated', payload);
  }
  const inserted = payload?.inserted ?? 0;
  if (inserted > 0) {
    notifyFeedIngestion({ inserted }).catch((err) => {
      console.error('[push] feed ingestion notify failed:', err?.message || err);
    });
  }
}

module.exports = {
  setIngestionSocket,
  emitFeedUpdated,
};
