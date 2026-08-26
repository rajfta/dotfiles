const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// helper.js is browser code; evaluate it in a CommonJS sandbox with no `window`
// so only the exported pure functions run.
const src = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'helper.js'), 'utf-8');
const shim = { exports: {} };
new Function('module', src)(shim);
const { renderTree, escapeHtml } = shim.exports;

test('escapeHtml escapes the five characters', () => {
  assert.equal(escapeHtml(`<a href="x">&'</a>`), '&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;');
});

test('renderTree renders topic, states, chosen option and nested children', () => {
  const html = renderTree({
    topic: 'Deviza storage',
    nodes: [
      { id: 'source', title: 'Rate source', state: 'resolved', chosen: 'MNB XML',
        children: [{ id: 'cadence', title: 'Fetch cadence', state: 'current' }] },
      { id: 'shape', title: 'Table <shape>', state: 'pending' },
    ],
  });
  assert.match(html, /<h3 class="tree-topic">Deviza storage<\/h3>/);
  assert.match(html, /<li class="node resolved"[^>]*>.*Rate source.*<span class="chosen">MNB XML<\/span>/s);
  assert.match(html, /<li class="node current"[^>]*>.*Fetch cadence/s);
  assert.match(html, /<li class="node pending"[^>]*>.*Table &lt;shape&gt;/s);
  assert.equal((html.match(/<ul/g) || []).length, 2, 'outer list plus one nested list');
});

test('renderTree tolerates null, garbage and unknown states', () => {
  assert.match(renderTree(null), /tree-empty/);
  assert.match(renderTree({ nodes: 'nope' }), /tree-empty/);
  assert.match(renderTree({ nodes: [{ title: 'x', state: 'weird' }] }), /node pending/);
});
