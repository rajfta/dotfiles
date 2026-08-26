const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, stop, sleep, TOKEN } = require('./helpers');

const PORT = 47004;

test('clicks and notes land in state/events; other messages do not', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-events-'));
  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);
    const ws = new WebSocket(`ws://127.0.0.1:${PORT}/?key=${TOKEN}`);
    await new Promise((r) => ws.addEventListener('open', r));
    ws.send(JSON.stringify({ type: 'click', choice: 'b', text: 'B Two column', id: null, timestamp: 1 }));
    ws.send(JSON.stringify({ type: 'note', text: 'B but without the enum', timestamp: 2 }));
    ws.send(JSON.stringify({ type: 'ping', timestamp: 3 }));
    ws.send(JSON.stringify({ type: 'note', text: '   ', timestamp: 4 }));
    await sleep(300);
    ws.close();

    const lines = fs.readFileSync(path.join(dir, 'state', 'events'), 'utf-8').trim().split('\n').map(JSON.parse);
    assert.deepEqual(lines.map((e) => e.type), ['click', 'note']);
    assert.equal(lines[1].text, 'B but without the enum');

    // A new screen appearing clears events — the tab is showing a fresh
    // question, so a stale click/note from the previous one must not linger.
    fs.mkdirSync(path.join(dir, 'content'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'content', 'next.html'), '<h2>next</h2>');
    await sleep(300);
    assert.equal(fs.existsSync(path.join(dir, 'state', 'events')), false);
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
