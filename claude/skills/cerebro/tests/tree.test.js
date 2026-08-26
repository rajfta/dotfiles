const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, sleep, TOKEN } = require('./helpers');

const PORT = 47003;
const pageJson = (body) => {
  const m = body.match(/<script id="cerebro-tree" type="application\/json">([\s\S]*?)<\/script>/);
  assert.ok(m, 'tree script tag present');
  return JSON.parse(m[1]);
};

test('the frame embeds state/tree.json, tolerates a bad file, and reloads when it changes', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-tree-'));
  fs.mkdirSync(path.join(dir, 'content')); fs.mkdirSync(path.join(dir, 'state'));
  fs.writeFileSync(path.join(dir, 'content', 'q1.html'), '<h2>Q1</h2>');
  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);

    // no tree yet → null, page still 200 with the sidebar mount point
    let res = await get(PORT, TOKEN, '/');
    assert.equal(res.status, 200);
    assert.equal(pageJson(res.body.toString()), null);
    assert.match(res.body.toString(), /<nav id="tree"/);

    // valid tree → embedded verbatim, with "</" made safe
    const tree = { topic: 'T </script>', nodes: [{ id: 'a', title: 'A', state: 'current' }] };
    fs.writeFileSync(path.join(dir, 'state', 'tree.json'), JSON.stringify(tree));
    res = await get(PORT, TOKEN, '/');
    assert.deepEqual(pageJson(res.body.toString()), tree);
    assert.doesNotMatch(res.body.toString(), /T <\/script>/);

    // invalid JSON → null, no crash
    fs.writeFileSync(path.join(dir, 'state', 'tree.json'), '{not json');
    res = await get(PORT, TOKEN, '/');
    assert.equal(res.status, 200);
    assert.equal(pageJson(res.body.toString()), null);

    // changing tree.json pushes a reload to connected clients
    const ws = new WebSocket(`ws://127.0.0.1:${PORT}/?key=${TOKEN}`);
    const gotReload = new Promise((resolve) => ws.addEventListener('message', (m) => { if (JSON.parse(m.data).type === 'reload') resolve(true); }));
    await new Promise((r) => ws.addEventListener('open', r));
    fs.writeFileSync(path.join(dir, 'state', 'tree.json'), JSON.stringify(tree));
    assert.equal(await Promise.race([gotReload, sleep(2000).then(() => false)]), true);
    ws.close();
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
