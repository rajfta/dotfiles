const { spawn } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');

const SERVER = path.join(__dirname, '..', 'scripts', 'server.cjs');
const TOKEN = 'cerebrotesttoken0123456789abcdef0123456789abcdef';

function startServer(port, dir, token = TOKEN, extraEnv = {}) {
  return spawn('node', [SERVER], {
    env: { ...process.env, CEREBRO_PORT: String(port), CEREBRO_DIR: dir, CEREBRO_TOKEN: token, ...extraEnv },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function waitForStarted(child, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    let out = '';
    const timer = setTimeout(() => reject(new Error('server did not start: ' + out)), timeoutMs);
    child.stdout.on('data', (c) => {
      out += c;
      const line = out.split('\n').find((l) => l.includes('"server-started"'));
      if (line) { clearTimeout(timer); resolve(JSON.parse(line)); }
    });
    child.stderr.on('data', (c) => { out += c; });
    child.on('exit', (code) => { clearTimeout(timer); reject(new Error('server exited ' + code + ': ' + out)); });
  });
}

function get(port, token, urlPath, headers = {}) {
  return new Promise((resolve, reject) => {
    const h = token ? { Cookie: `cerebro-key-${port}=${token}`, ...headers } : headers;
    http.get({ host: '127.0.0.1', port, path: urlPath, headers: h }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    }).on('error', reject);
  });
}

function stop(child) {
  return new Promise((resolve) => {
    if (child.exitCode !== null) return resolve();
    child.once('exit', () => resolve());
    child.kill('SIGTERM');
    setTimeout(() => { try { child.kill('SIGKILL'); } catch (e) {} }, 1000).unref();
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

module.exports = { startServer, waitForStarted, get, stop, sleep, TOKEN };
