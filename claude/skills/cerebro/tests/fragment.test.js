const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { startServer, waitForStarted, get, stop, sleep, TOKEN } = require('./helpers');

const PORT = 47005;
const PORT2 = 47006;

test('a fragment screen wraps into the frame; a full document bypasses it', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-fragment-'));
  fs.mkdirSync(path.join(dir, 'content'));
  fs.mkdirSync(path.join(dir, 'state'));
  fs.writeFileSync(path.join(dir, 'content', 'q1.html'), '<h2>FRAGMENT-MARKER-Q1</h2>');

  const child = startServer(PORT, dir);
  try {
    await waitForStarted(child);

    // Fragment screen: wrapped in the frame, placeholder consumed, marker
    // lands inside #frame-content (not e.g. stolen by an earlier occurrence
    // of the same literal marker text elsewhere in the template).
    let res = await get(PORT, TOKEN, '/');
    const body1 = res.body.toString();
    assert.equal(res.status, 200);
    assert.match(body1, /FRAGMENT-MARKER-Q1/);
    assert.match(body1, /<nav id="tree"/);
    assert.match(body1, /id="note-form"/);
    assert.doesNotMatch(body1, /<!-- CONTENT -->/);
    assert.match(body1, /<div id="frame-content">\s*<h2>FRAGMENT-MARKER-Q1<\/h2>/);

    // A newer full document bypasses the frame entirely.
    await sleep(20);
    fs.writeFileSync(
      path.join(dir, 'content', 'full.html'),
      '<!DOCTYPE html><html><head><title>FULL</title></head><body><p>FULL-DOC-MARKER</p></body></html>'
    );
    res = await get(PORT, TOKEN, '/');
    const body2 = res.body.toString();
    assert.equal(res.status, 200);
    assert.match(body2, /FULL-DOC-MARKER/);
    assert.doesNotMatch(body2, /<nav id="tree"/);
    assert.match(body2, /nextReconnectDelay/);
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('wrapInFrame does not let $-patterns in the fragment mangle the frame', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cerebro-dollar-'));
  fs.mkdirSync(path.join(dir, 'content'));
  fs.mkdirSync(path.join(dir, 'state'));
  const marker = '<pre>echo $$ &amp;&amp; x = \'$\' + n; y = "$&amp;"</pre>';
  fs.writeFileSync(path.join(dir, 'content', 'older.html'), '<h2>older</h2>');
  await sleep(20);
  fs.writeFileSync(path.join(dir, 'content', 'dollar-pattern.html'), marker);

  const child = startServer(PORT2, dir);
  try {
    await waitForStarted(child);
    const res = await get(PORT2, TOKEN, '/');
    const body = res.body.toString();
    assert.equal(res.status, 200);

    const markerOccurrences = body.split(marker).length - 1;
    assert.equal(markerOccurrences, 1, 'fragment with $-patterns must survive substitution exactly once, verbatim');

    const titleOccurrences = body.split('<title>Cerebro</title>').length - 1;
    assert.equal(titleOccurrences, 1, 'a mangled substitution duplicates the template (extra <title>)');
  } finally {
    await stop(child);
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
