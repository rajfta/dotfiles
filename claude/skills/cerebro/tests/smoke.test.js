const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, TOKEN } = require('./helpers');

const PORT = 47001;

test('server starts with CEREBRO_* env, serves the frame under a cerebro cookie, and rejects no-key requests', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-smoke-'));
  const child = startServer(PORT, dir);
  try {
    const info = await waitForStarted(child);
    assert.equal(info.port, PORT);
    assert.match(info.url, /\?key=/);
    assert.equal(info.screen_dir, path.join(dir, 'content'));

    const denied = await get(PORT, null, '/');
    assert.equal(denied.status, 403);

    const ok = await get(PORT, TOKEN, '/');
    assert.equal(ok.status, 200);
    const body = ok.body.toString();
    assert.match(body, /Cerebro/);
    assert.doesNotMatch(body, /brainstorm/i);
    assert.doesNotMatch(body, /superpowers|prime ?radiant/i);
    assert.match(ok.headers['set-cookie'][0], new RegExp('^cerebro-key-' + PORT + '='));
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
