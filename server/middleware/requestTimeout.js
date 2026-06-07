/**
 * Abort long-running HTTP handlers with 504 when the client is still connected.
 * Clears the timer when the response finishes or the connection closes.
 */
function requestTimeout(ms) {
  const timeoutMs = Math.max(1000, Number(ms) || 60000);
  return (req, res, next) => {
    const timer = setTimeout(() => {
      if (!res.headersSent) {
        res.status(504).json({
          success: false,
          message: 'Request timed out. Please try again.',
        });
      }
    }, timeoutMs);
    timer.unref?.();

    const clear = () => clearTimeout(timer);
    res.on('finish', clear);
    res.on('close', clear);
    next();
  };
}

function chatRequestTimeoutMs() {
  return Math.min(
    120000,
    Math.max(15000, Number(process.env.CHAT_REQUEST_TIMEOUT_MS || 60000)),
  );
}

function translateRequestTimeoutMs() {
  return Math.min(
    120000,
    Math.max(15000, Number(process.env.TRANSLATE_REQUEST_TIMEOUT_MS || 90000)),
  );
}

module.exports = {
  requestTimeout,
  chatRequestTimeoutMs,
  translateRequestTimeoutMs,
};
