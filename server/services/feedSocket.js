const { notifyFeedIngestion } = require('../utils/notifications');
const { invalidateFeedCaches } = require('../utils/feedResponseCache');

let ingestionSocket = null;

function setIngestionSocket(io) {
  ingestionSocket = io;
}

async function emitFeedUpdated(payload) {
  await invalidateFeedCaches();
  if (ingestionSocket) {
    ingestionSocket.to('all').emit('feed_updated', payload);
  }
  const inserted = payload?.inserted ?? 0;
  if (inserted > 0) {
    const source = payload?.source || payload?.type || 'news';
    notifyFeedIngestion({ inserted, source }).catch((err) => {
      console.error('[push] feed ingestion notify failed:', err?.message || err);
    });
  }
}

module.exports = {
  setIngestionSocket,
  emitFeedUpdated,
};
