let ingestionSocket = null;

function setIngestionSocket(io) {
  ingestionSocket = io;
}

function emitFeedUpdated(payload) {
  if (ingestionSocket) {
    ingestionSocket.to('all').emit('feed_updated', payload);
  }
}

module.exports = {
  setIngestionSocket,
  emitFeedUpdated,
};
