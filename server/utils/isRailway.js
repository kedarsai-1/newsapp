/** True when running on Railway (used for memory-safe defaults). */
function isRailwayHost() {
  return Boolean(process.env.RAILWAY_ENVIRONMENT || process.env.RAILWAY_PROJECT_ID);
}

module.exports = { isRailwayHost };
