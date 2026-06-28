const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const os = require('os');

const {
  rehostExternalImageForIngest,
  isLocalMediaUrl,
  localMediaDir,
} = require('../../utils/rehostExternalImage');

describe('rehostExternalImage', () => {
  let tmpDir;

  before(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'newsapp-media-'));
    process.env.INGEST_LOCAL_MEDIA_DIR = tmpDir;
    process.env.MEDIA_PUBLIC_BASE_URL = 'http://test.local';
    process.env.INGEST_REHOST_IMAGES = 'true';
    process.env.CLOUDINARY_CLOUD_NAME = '';
  });

  after(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('detects local media URLs', () => {
    assert.equal(isLocalMediaUrl('http://test.local/media/ingest/abc.jpg'), true);
    assert.equal(isLocalMediaUrl('https://cdn.example.com/a.jpg'), false);
  });

  it('rehostExternalImageForIngest saves to local disk when Cloudinary unavailable', async () => {
    const result = await rehostExternalImageForIngest(
      'https://ntvtelugu.com/wp-content/uploads/2026/06/mib-1-1024x576.jpg',
      { referer: 'https://ntvtelugu.com/' },
    );
    assert.equal(result.ok, true);
    assert.equal(result.backend, 'local');
    assert.match(result.url, /^http:\/\/test\.local\/media\/ingest\/.+\.jpg$/);
    const files = fs.readdirSync(localMediaDir());
    assert.ok(files.length >= 1);
  });
});
