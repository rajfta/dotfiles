const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const SCRIPTS = path.join(__dirname, '..', 'scripts');
const FILES = ['server.cjs', 'frame-template.html', 'helper.js', 'start-server.sh', 'stop-server.sh'];
const FORBIDDEN = /brainstorm|superpowers|prime ?radiant/i;

for (const f of FILES) {
  test(`${f} carries no upstream brand strings`, () => {
    const lines = fs.readFileSync(path.join(SCRIPTS, f), 'utf-8').split('\n').map((l, i) => (f === 'server.cjs' && i === 0 ? '' : l));
    const hits = lines.map((l, i) => (FORBIDDEN.test(l) ? `${i + 1}: ${l.trim()}` : null)).filter(Boolean);
    assert.deepEqual(hits, []);
  });
}
