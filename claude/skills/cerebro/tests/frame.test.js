const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const frame = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'frame-template.html'), 'utf-8');
const helper = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'helper.js'), 'utf-8');

test('frame provides the component CSS the visual guide documents', () => {
  for (const sel of ['.gallery', '.compare', '.pane-title', '.option[data-recommended]', '.pros-cons', '.note-status', 'table']) {
    assert.ok(frame.includes(sel), `missing CSS for ${sel}`);
  }
});

test('frame has the note form, the tree mount, both placeholders and the mermaid loader', () => {
  assert.match(frame, /<form id="note-form"/);
  assert.match(frame, /<textarea id="note-text"/);
  assert.match(frame, /<nav id="tree"/);
  assert.ok(frame.includes('<!-- CONTENT -->') && frame.includes('<!-- TREE -->') && frame.includes('<!-- BRANDING -->'));
  assert.match(frame, /cdn\.jsdelivr\.net\/npm\/mermaid@11/);
});

test('helper wires the note form and gallery selection', () => {
  assert.match(helper, /note-form/);
  assert.match(helper, /type: 'note'/);
  assert.match(helper, /\.gallery/);
});
