const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, TOKEN } = require('./helpers');

const PORT = 47002;
// Smallest valid PNG (1x1, transparent).
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');

test('/inbox/* serves images from the session inbox and nothing else', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-inbox-'));
  fs.mkdirSync(path.join(dir, 'inbox'));
  fs.writeFileSync(path.join(dir, 'inbox', 'design-a.png'), PNG);
  fs.writeFileSync(path.join(dir, 'inbox', 'notes.webp'), PNG);
  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);

    const png = await get(PORT, TOKEN, '/inbox/design-a.png');
    assert.equal(png.status, 200);
    assert.equal(png.headers['content-type'], 'image/png');
    assert.ok(png.body.equals(PNG));

    const webp = await get(PORT, TOKEN, '/inbox/notes.webp');
    assert.equal(webp.headers['content-type'], 'image/webp');

    assert.equal((await get(PORT, TOKEN, '/inbox/missing.png')).status, 404);
    assert.equal((await get(PORT, TOKEN, '/inbox/')).status, 404);
    assert.equal((await get(PORT, TOKEN, '/inbox/..%2Fstate%2Fserver-info')).status, 404);
    assert.equal((await get(PORT, TOKEN, '/inbox/.hidden')).status, 404);
    assert.equal((await get(PORT, null, '/inbox/design-a.png')).status, 403);
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
