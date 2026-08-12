process.on('uncaughtException', (err) => {
  console.error('UNCAUGHT:', err.message, err.stack);
});
process.on('unhandledRejection', (err) => {
  console.error('UNHANDLED:', err);
});

const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 3000;
const DATA_DIR = path.join(__dirname, 'data');
const KEYS_FILE = path.join(DATA_DIR, 'keys.json');
const USERS_FILE = path.join(DATA_DIR, 'users.json');
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'kabe-admin-secret-change-me';
const adminSessions = new Map();

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

function loadJSON(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { return fallback; }
}
function saveJSON(file, data) {
  try { fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8'); } catch (e) { console.error('saveJSON error:', e.message); }
}

let keysData = loadJSON(KEYS_FILE, { keys: [] });
let usersData = loadJSON(USERS_FILE, { users: [] });

function genKey() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let k = 'KABE-';
  for (let i = 0; i < 16; i++) k += chars[crypto.randomInt(chars.length)];
  return k;
}

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
const server = http.createServer(app);

const STATIC_DIR = path.join(__dirname, '..');
app.use(express.static(STATIC_DIR));

app.get('/api/health', (req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

app.get('/api/debug', (req, res) => {
  try {
    const files = fs.readdirSync(STATIC_DIR);
    res.json({ dir: STATIC_DIR, files });
  } catch (e) {
    res.json({ error: e.message, dir: STATIC_DIR });
  }
});

function requireAdmin(req, res, next) {
  const token = req.headers['x-admin-token'];
  if (!token || !adminSessions.has(token)) {
    return res.status(403).json({ error: 'Acesso negado' });
  }
  next();
}

app.get('/api/keys', requireAdmin, (req, res) => {
  res.json(keysData);
});

app.post('/api/keys/generate', requireAdmin, (req, res) => {
  const count = Math.min(parseInt(req.body.count) || 1, 50);
  const newKeys = [];
  for (let i = 0; i < count; i++) {
    const key = genKey();
    keysData.keys.push({ key, active: true, created: new Date().toISOString(), usedBy: null });
    newKeys.push(key);
  }
  saveJSON(KEYS_FILE, keysData);
  res.json({ keys: newKeys, total: keysData.keys.length });
});

app.post('/api/keys/delete', requireAdmin, (req, res) => {
  const { key } = req.body;
  keysData.keys = keysData.keys.filter(k => k.key !== key);
  saveJSON(KEYS_FILE, keysData);
  res.json({ ok: true, total: keysData.keys.length });
});

app.post('/api/keys/toggle', requireAdmin, (req, res) => {
  const { key } = req.body;
  const k = keysData.keys.find(x => x.key === key);
  if (k) { k.active = !k.active; saveJSON(KEYS_FILE, keysData); }
  res.json({ ok: !!k, active: k ? k.active : false });
});

app.post('/api/auth/register', (req, res) => {
  const { key, user, pass } = req.body;
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '';
  if (!key || !user || !pass) return res.status(400).json({ error: 'Campos obrigatorios' });
  const k = keysData.keys.find(x => x.key === key);
  if (!k) return res.status(400).json({ error: 'Key invalida' });
  if (!k.active) return res.status(400).json({ error: 'Key desativada' });
  if (k.usedBy) return res.status(400).json({ error: 'Key ja utilizada' });
  if (usersData.users.find(u => u.user === user)) return res.status(400).json({ error: 'Usuario ja existe' });
  k.usedBy = user;
  usersData.users.push({ user, pass, ip, created: new Date().toISOString() });
  saveJSON(KEYS_FILE, keysData);
  saveJSON(USERS_FILE, usersData);
  res.json({ ok: true });
});

app.post('/api/auth/login', (req, res) => {
  const { user, pass } = req.body;
  const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || '';
  const u = usersData.users.find(x => x.user === user && x.pass === pass);
  if (!u) return res.status(400).json({ error: 'Usuario ou senha incorretos' });
  u.ip = ip;
  u.lastIp = ip;
  u.lastLogin = new Date().toISOString();
  saveJSON(USERS_FILE, usersData);
  res.json({ ok: true, user: u.user });
});

app.post('/api/admin/login', (req, res) => {
  const { password } = req.body;
  if (!password || password !== ADMIN_SECRET) {
    return res.status(403).json({ error: 'Senha incorreta' });
  }
  const token = crypto.randomBytes(32).toString('hex');
  adminSessions.set(token, { created: Date.now() });
  setTimeout(() => { adminSessions.delete(token); }, 60 * 60 * 1000);
  res.json({ ok: true, token });
});

app.get('/api/admin/users', requireAdmin, (req, res) => {
  res.json(usersData);
});

app.post('/api/admin/delete-user', requireAdmin, (req, res) => {
  const { user } = req.body;
  usersData.users = usersData.users.filter(u => u.user !== user);
  const k = keysData.keys.find(x => x.usedBy === user);
  if (k) { k.usedBy = null; saveJSON(KEYS_FILE, keysData); }
  saveJSON(USERS_FILE, usersData);
  res.json({ ok: true });
});

const agents = new Map();

app.post('/api/agent/register', (req, res) => {
  const { key, id } = req.body;
  if (!key) return res.status(400).json({ error: 'Key obrigatoria' });
  if (!agents.has(key)) {
    agents.set(key, { id: id || 'unknown', pending: [], output: [], lastSeen: Date.now() });
  }
  agents.get(key).lastSeen = Date.now();
  res.json({ ok: true });
});

app.get('/api/agent/poll', (req, res) => {
  const { key } = req.query;
  const agent = agents.get(key);
  if (!agent) return res.json(null);
  agent.lastSeen = Date.now();
  if (agent.pending.length > 0) {
    res.json(agent.pending.shift());
  } else {
    res.json(null);
  }
});

app.post('/api/agent/command', (req, res) => {
  const { key, cmd } = req.body;
  const agent = agents.get(key);
  if (!agent) return res.status(404).json({ error: 'Agent nao conectado' });
  const id = Date.now();
  agent.pending.push({ id, cmd });
  res.json({ ok: true, id });
});

app.post('/api/agent/output', (req, res) => {
  const { key, id, exit, data } = req.body;
  const agent = agents.get(key);
  if (!agent) return res.status(404).json({ error: 'Agent nao encontrado' });
  let output = '';
  try { output = Buffer.from(data || '', 'base64').toString('utf8'); } catch (e) { output = data || ''; }
  agent.output.push({ id: parseInt(id), exit: parseInt(exit), output, time: Date.now() });
  res.json({ ok: true });
});

app.get('/api/agent/output', (req, res) => {
  const { key } = req.query;
  const agent = agents.get(key);
  if (!agent) return res.json([]);
  const out = agent.output.splice(0);
  res.json(out);
});

app.get('/api/agent/list', (req, res) => {
  const list = [];
  agents.forEach((v, k) => {
    list.push({ key: k, id: v.id, lastSeen: v.lastSeen, online: (Date.now() - v.lastSeen) < 15000 });
  });
  res.json(list);
});

app.post('/api/agent/config', (req, res) => {
  const { key, serverUrl } = req.body;
  if (!key || !serverUrl) return res.status(400).json({ error: 'Key e serverUrl obrigatorios' });
  res.json({ ok: true, server: serverUrl, key });
});

const HS_ROOT = path.join(__dirname, '..', 'files', 'hs');
const HS_CACHE_FILE = 'cache_res.~2BrPJlgpDAnfyUCp~2Biox5bwsZlQQ~3D';

const HS_MODES = {
  limpo: { label: 'Limpo', desc: 'Sem HS, jogo original', files: [HS_CACHE_FILE] },
  hsalto: { label: 'HS Alto', desc: 'Capa acima da cabeca', files: [HS_CACHE_FILE] },
  hsaltoplus: { label: 'HS Alto+', desc: 'Capa acima e dos lados', files: [HS_CACHE_FILE] },
  hsneck: { label: 'HS Pescoco', desc: 'Capa no pescoco', files: [HS_CACHE_FILE] },
  hspeito: { label: 'HS Peito', desc: 'Capa no peito', files: [HS_CACHE_FILE] }
};

function hsModeList() {
  const list = {};
  for (const id in HS_MODES) {
    const m = HS_MODES[id];
    list[id] = {
      label: m.label,
      desc: m.desc,
      files: m.files.map(f => {
        const lp = path.join(HS_ROOT, id, f);
        let size = 0;
        try { size = fs.statSync(lp).size; } catch (e) {}
        return { name: f, size, exists: size > 0 };
      })
    };
  }
  return list;
}

function stripAnsi(s) {
  return String(s || '').replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\x1b\][^\x07]*\x07/g, '').replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');
}
function filterHoloLog(raw) {
  const lines = stripAnsi(raw).split(/\r?\n/).map(l => l.trim()).filter(l => l);
  const keep = [];
  const important = /inject|restore|revert|error|fail|done|not found|deploy|game file|hologram|assets|patched|already/i;
  for (const l of lines) {
    if (important.test(l) || l.indexOf('\u2714') !== -1 || l.indexOf('\u2718') !== -1) {
      keep.push(l);
    }
  }
  if (keep.length === 0 && lines.length > 0) {
    const last = lines[lines.length - 1];
    keep.push(last.length > 120 ? last.slice(0, 120) + '...' : last);
  }
  return keep.slice(-15);
}

function agentExec(key, cmd, timeout) {
  timeout = timeout || 30000;
  return new Promise((resolve, reject) => {
    const agent = agents.get(key);
    if (!agent) return reject(new Error('Agent offline'));
    if (!agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return reject(new Error('Agent offline'));
    const id = Date.now();
    agent.pending.push({ id, cmd });
    let waited = 0;
    const iv = setInterval(() => {
      waited += 300;
      const idx = agent.output.findIndex(o => o.id === id);
      if (idx !== -1) {
        const out = agent.output.splice(idx, 1)[0];
        clearInterval(iv);
        resolve({ exit: out.exit, output: out.output || '' });
      } else if (waited >= timeout) {
        clearInterval(iv);
        reject(new Error('Timeout'));
      }
    }, 300);
  });
}

function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

const HS_TARGET_NORMAL = '/data/user/0/com.dts.freefireth/files/contentcache/Compulsory/android/gameassetbundles/';
const HS_TARGET_MAX = '/data/user/0/com.dts.freefiremax/files/contentcache/Compulsory/android/gameassetbundles/';
function hsTarget(game) { return game === 'max' ? HS_TARGET_MAX : HS_TARGET_NORMAL; }

app.post('/api/agent/hs-inject', (req, res) => {
  const { key, mode, game } = req.body;
  if (!key || !mode) return res.status(400).json({ error: 'Key e mode obrigatorios' });
  const agent = agents.get(key);
  if (!agent || !agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return res.status(400).json({ error: 'Agent offline' });
  const m = HS_MODES[mode];
  if (!m) return res.status(400).json({ error: 'Modo invalido' });
  const g = game === 'max' ? 'max' : 'normal';
  const target = hsTarget(g);
  const modeName = { limpo: 'Limpo', hsalto: 'Alto', hsaltoplus: 'Alto+', hsneck: 'Pescoco', hspeito: 'Peito' }[mode] || mode;
  const gameName = g === 'max' ? 'Free Fire MAX' : 'Free Fire';
  res.json({ ok: true, logs: ['Injetando...'], pending: true });
  (async () => {
    const logs = [];
    try {
      for (const f of m.files) {
        const local = path.join(HS_ROOT, mode, f);
        if (!fs.existsSync(local)) { logs.push('ERRO: Arquivo nao encontrado'); agent.hsResult = logs; return; }
        const data = fs.readFileSync(local);
        const b64 = data.toString('base64');
        const tmp = '/data/local/tmp/.kabe_hs.b64';
        const tmpBin = '/data/local/tmp/.kabe_hs.bin';
        await agentExec(key, 'rm -f ' + q(tmp) + ' ' + q(tmpBin) + ' && mkdir -p ' + q(target), 20000);
        for (let i = 0; i < b64.length; i += 50000) {
          const chunk = b64.slice(i, i + 50000);
          await agentExec(key, 'echo -n ' + q(chunk) + ' >> ' + q(tmp), 20000);
        }
        await agentExec(key, 'base64 -d ' + q(tmp) + ' > ' + q(tmpBin) + ' && cp -f ' + q(tmpBin) + ' ' + q(target + f) + ' && chmod 666 ' + q(target + f) + ' && rm -f ' + q(tmp) + ' ' + q(tmpBin), 20000);
      }
      logs.push('HS ' + modeName + ' injetado em ' + gameName);
    } catch (e) {
      logs.push('ERRO: ' + e.message);
    }
    agent.hsResult = logs;
  })();
});

app.get('/api/agent/hs-result', (req, res) => {
  const { key } = req.query;
  const agent = agents.get(key);
  if (!agent) return res.json({ done: true, logs: ['Agent offline'] });
  if (agent.hsResult) {
    const logs = agent.hsResult;
    delete agent.hsResult;
    return res.json({ done: true, logs });
  }
  res.json({ done: false });
});

const HOLO_SCRIPT = path.join(__dirname, '..', 'files', 'kabe_holo.sh');
const HOLO = {
  o1: 'f00cef0f0b1ba2647be6f2e521768a72',
  n1: '216a7113b7f1bc74eb2289d47f2a406d',
  og: 'fb149d0db86305646b187dbe429d8c23',
  ng: '83dcbeac62c7ce543811b947f6fc12e5',
  bakDir: '/data/local/tmp/.kabe_private_core',
  fileName: 'split_asset_pack_install_time.apk.pdcache'
};

function holoPath(game) {
  const pkg = game === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  return '/data/user/0/' + pkg + '/files/' + HOLO.fileName;
}

app.post('/api/agent/holo-patch', async (req, res) => {
  const { key, game, mode } = req.body;
  if (!key) return res.status(400).json({ error: 'Key obrigatoria' });
  const agent = agents.get(key);
  if (!agent || !agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return res.status(400).json({ error: 'Agent offline' });
  const g = game === 'max' ? 'max' : 'normal';
  const pkg = g === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const logs = [];
  try {
    if (!fs.existsSync(HOLO_SCRIPT)) return res.json({ ok: false, error: 'Script holo nao encontrado', logs: ['Script nao encontrado no servidor'] });
    logs.push('Enviando script...');
    const scriptData = fs.readFileSync(HOLO_SCRIPT);
    const b64 = scriptData.toString('base64');
    const remoteScript = '/data/local/tmp/kabe_holo.sh';
    const tmpB64 = '/data/local/tmp/.kabe_holo.b64';
    await agentExec(key, 'rm -f ' + q(tmpB64) + ' ' + q(remoteScript), 15000);
    for (let i = 0; i < b64.length; i += 20000) {
      await agentExec(key, 'echo -n ' + q(b64.slice(i, i + 20000)) + ' >> ' + q(tmpB64), 15000);
    }
    await agentExec(key, 'base64 -d ' + q(tmpB64) + ' > ' + q(remoteScript) + ' && chmod 777 ' + q(remoteScript) + ' && rm -f ' + q(tmpB64), 15000);
    logs.push('Script enviado');
    const m = parseInt(mode, 10) === 2 ? 2 : 1;
    const isRestore = parseInt(mode, 10) === 3;
    let choice;
    if (g === 'max') { choice = isRestore ? 3 : (m === 1 ? 1 : 2); }
    else { choice = isRestore ? 6 : (m === 1 ? 4 : 5); }
    logs.push('Executando choice ' + choice + '...');
    const r = await agentExec(key, 'sh ' + q(remoteScript) + ' ' + choice, 30000);
    if (r.output) { filterHoloLog(r.output).forEach(ln => logs.push(ln)); }
    await agentExec(key, 'am force-stop ' + pkg, 15000);
    logs.push('Jogo encerrado');
    res.json({ ok: true, logs });
  } catch (e) {
    logs.push('ERRO: ' + e.message);
    res.json({ ok: false, error: e.message, logs });
  }
});

app.post('/api/agent/holo-restore', async (req, res) => {
  const { key, game } = req.body;
  if (!key) return res.status(400).json({ error: 'Key obrigatoria' });
  const agent = agents.get(key);
  if (!agent || !agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return res.status(400).json({ error: 'Agent offline' });
  const g = game === 'max' ? 'max' : 'normal';
  const pkg = g === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const logs = [];
  try {
    if (!fs.existsSync(HOLO_SCRIPT)) return res.json({ ok: false, error: 'Script holo nao encontrado', logs: ['Script nao encontrado'] });
    const scriptData = fs.readFileSync(HOLO_SCRIPT);
    const b64 = scriptData.toString('base64');
    const remoteScript = '/data/local/tmp/kabe_holo.sh';
    const tmpB64 = '/data/local/tmp/.kabe_holo.b64';
    await agentExec(key, 'rm -f ' + q(tmpB64) + ' ' + q(remoteScript), 15000);
    for (let i = 0; i < b64.length; i += 20000) {
      await agentExec(key, 'echo -n ' + q(b64.slice(i, i + 20000)) + ' >> ' + q(tmpB64), 15000);
    }
    await agentExec(key, 'base64 -d ' + q(tmpB64) + ' > ' + q(remoteScript) + ' && chmod 777 ' + q(remoteScript) + ' && rm -f ' + q(tmpB64), 15000);
    logs.push('Script enviado');
    const choice = g === 'max' ? 3 : 6;
    logs.push('Restaurando choice ' + choice + '...');
    const r = await agentExec(key, 'sh ' + q(remoteScript) + ' ' + choice, 30000);
    if (r.output) filterHoloLog(r.output).forEach(ln => logs.push(ln));
    await agentExec(key, 'am force-stop ' + pkg, 15000);
    logs.push('Jogo encerrado');
    res.json({ ok: true, logs });
  } catch (e) {
    logs.push('ERRO: ' + e.message);
    res.json({ ok: false, error: e.message, logs });
  }
});

const wss = new WebSocketServer({ server, path: '/ws' });
wss.on('connection', (ws) => {
  try {
    ws.send(JSON.stringify({ type: 'engine_status', mode: 'live', ssh: false }));
    ws.send(JSON.stringify({ type: 'hs_list', modes: hsModeList(), target: HS_TARGET_NORMAL }));
  } catch (e) {}
  ws.on('close', () => {});
  ws.on('error', () => {});
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('KABE PRIVATE rodando na porta ' + PORT);
});

setInterval(() => {
  http.get('http://localhost:' + PORT + '/api/health').on('error', () => {});
}, 14 * 60 * 1000);
