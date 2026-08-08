// ═══════════════════════════════════════════════════════════
//   KABE PRIVATE — Bridge SSH local
//   Roda no PC e serve o site + executa comandos reais
//   no celular via SSH (Termux com sshd + root).
//
//   Como rodar:
//     1) cd server
//     2) npm install
//     3) node server.js
//    Abra http://localhost:3000
// ═══════════════════════════════════════════════════════════

const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const { Client } = require('ssh2');

const PORT = process.env.PORT || 3000;
const DATA_DIR = path.join(__dirname, 'data');
const KEYS_FILE = path.join(DATA_DIR, 'keys.json');
const USERS_FILE = path.join(DATA_DIR, 'users.json');

// Garantir diretorio de dados
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

function loadJSON(file, fallback) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { return fallback; }
}
function saveJSON(file, data) {
  fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
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
const wss = new WebSocketServer({ server, path: '/ws' });

// Serve o site que fica na pasta acima (kabe-private/index.html)
const STATIC_DIR = path.join(__dirname, '..');
app.use(express.static(STATIC_DIR));

// Debug: listar arquivos na raiz
app.get('/api/debug', (req, res) => {
  try {
    const files = fs.readdirSync(STATIC_DIR);
    res.json({ dir: STATIC_DIR, files });
  } catch (e) {
    res.json({ error: e.message, dir: STATIC_DIR });
  }
});

// Carrega a chave privada salva na máquina (para não precisar colar)
const KEY_CANDIDATES = [
  path.join(process.env.USERPROFILE || 'C:\\Users\\klebe', '.ssh', 'kabe_id_rsa'),
  path.join(process.env.USERPROFILE || 'C:\\Users\\klebe', 'Documents', 'passador', 'ssh_keys', 'kabe_id_rsa'),
  path.join(process.env.USERPROFILE || 'C:\\Users\\klebe', 'Documents', 'passador', 'dist', 'passbk', 'kabe_id_rsa')
];
app.get('/api/key', (req, res) => {
  for (const p of KEY_CANDIDATES) {
    try {
      if (fs.existsSync(p)) return res.json({ key: fs.readFileSync(p, 'utf8'), path: p });
    } catch (e) {}
  }
  return res.status(404).json({ error: 'Chave nao encontrada' });
});

// ── API: Keys ─────────────────────────────────────────────
app.get('/api/keys', (req, res) => {
  res.json(keysData);
});

app.post('/api/keys/generate', (req, res) => {
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

app.post('/api/keys/delete', (req, res) => {
  const { key } = req.body;
  keysData.keys = keysData.keys.filter(k => k.key !== key);
  saveJSON(KEYS_FILE, keysData);
  res.json({ ok: true, total: keysData.keys.length });
});

app.post('/api/keys/toggle', (req, res) => {
  const { key } = req.body;
  const k = keysData.keys.find(x => x.key === key);
  if (k) { k.active = !k.active; saveJSON(KEYS_FILE, keysData); }
  res.json({ ok: !!k, active: k ? k.active : false });
});

// ── API: Auth ─────────────────────────────────────────────
app.post('/api/auth/register', (req, res) => {
  const { key, user, pass } = req.body;
  if (!key || !user || !pass) return res.status(400).json({ error: 'Campos obrigatorios' });
  const k = keysData.keys.find(x => x.key === key);
  if (!k) return res.status(400).json({ error: 'Key invalida' });
  if (!k.active) return res.status(400).json({ error: 'Key desativada' });
  if (k.usedBy) return res.status(400).json({ error: 'Key ja utilizada' });
  if (usersData.users.find(u => u.user === user)) return res.status(400).json({ error: 'Usuario ja existe' });
  k.usedBy = user;
  usersData.users.push({ user, pass, created: new Date().toISOString() });
  saveJSON(KEYS_FILE, keysData);
  saveJSON(USERS_FILE, usersData);
  res.json({ ok: true });
});

app.post('/api/auth/login', (req, res) => {
  const { user, pass } = req.body;
  const u = usersData.users.find(x => x.user === user && x.pass === pass);
  if (!u) return res.status(400).json({ error: 'Usuario ou senha incorretos' });
  res.json({ ok: true, user: u.user });
});

// ── API: Admin ────────────────────────────────────────────
app.get('/api/admin/users', (req, res) => {
  res.json(usersData);
});

app.post('/api/admin/delete-user', (req, res) => {
  const { user } = req.body;
  usersData.users = usersData.users.filter(u => u.user !== user);
  const k = keysData.keys.find(x => x.usedBy === user);
  if (k) { k.usedBy = null; saveJSON(KEYS_FILE, keysData); }
  saveJSON(USERS_FILE, usersData);
  res.json({ ok: true });
});

// ── API: Gerar chaves SSH ─────────────────────────────────
app.post('/api/ssh/generate-keys', (req, res) => {
  try {
    const { generateKeyPairSync } = require('ssh2').utils;
    const type = String(req.body.type || 'rsa') === 'ed25519' ? 'ed25519' : 'rsa';
    const opts = type === 'ed25519' ? {} : { bits: 2048 };
    const k = generateKeyPairSync(type, opts);
    res.json({
      privateKey: k.private,
      publicKey: k.public + (req.body.comment || ' kabe'),
      type
    });
  } catch (e) {
    res.status(500).json({ error: 'Erro ao gerar chaves: ' + e.message });
  }
});

// ── KABE Agent API (reversa: phone → server) ─────────────
const agents = new Map(); // key → { ws, pending, output }

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

// ── Agent: utilitarios ──
function stripAnsi(s) {
  return String(s || '').replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\x1b\][^\x07]*\x07/g, '').replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');
}
function filterHoloLog(raw) {
  const lines = stripAnsi(raw).split(/\r?\n/).map(l => l.trim()).filter(l => l);
  const keep = [];
  const important = /inject|restore|revert|error|fail|done|not found|deploy|game file|hologram|assets|patched|already/i;
  for (const l of lines) {
    if (important.test(l) || l.indexOf('✔') !== -1 || l.indexOf('✘') !== -1) {
      keep.push(l);
    }
  }
  if (keep.length === 0 && lines.length > 0) {
    const last = lines[lines.length - 1];
    keep.push(last.length > 120 ? last.slice(0, 120) + '...' : last);
  }
  return keep.slice(-15);
}
function filterHsLog(raw) {
  const lines = stripAnsi(raw).split(/\r?\n/).map(l => l.trim()).filter(l => l);
  return lines.slice(-5);
}

// ── Agent: executar comando via agent e esperar resultado ──
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
      waited += 500;
      const idx = agent.output.findIndex(o => o.id === id);
      if (idx !== -1) {
        const out = agent.output.splice(idx, 1)[0];
        clearInterval(iv);
        resolve({ exit: out.exit, output: out.output || '' });
      } else if (waited >= timeout) {
        clearInterval(iv);
        reject(new Error('Timeout aguardando resultado'));
      }
    }, 500);
  });
}

function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

// ── Agent: HS Injecao ──
app.post('/api/agent/hs-inject', async (req, res) => {
  const { key, mode, game } = req.body;
  if (!key || !mode) return res.status(400).json({ error: 'Key e mode obrigatorios' });
  const agent = agents.get(key);
  if (!agent || !agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return res.status(400).json({ error: 'Agent offline' });

  const m = HS_MODES[mode];
  if (!m) return res.status(400).json({ error: 'Modo invalido' });

  const g = game === 'max' ? 'max' : 'normal';
  const target = hsTarget(g);
  const logs = [];

  try {
    for (const f of m.files) {
      const local = path.join(HS_ROOT, mode, f);
      if (!fs.existsSync(local)) throw new Error('Arquivo nao encontrado: ' + f);
      const data = fs.readFileSync(local);
      const b64 = data.toString('base64');
      const tmpB64 = '/data/local/tmp/.kabe_hs.b64';
      const tmpBin = '/data/local/tmp/.kabe_hs.bin';

      // Limpar + criar dir + enviar base64 em UM comando so
      await agentExec(key, 'rm -f ' + q(tmpB64) + ' ' + q(tmpBin) + ' && mkdir -p ' + q(target), 15000);

      // Enviar base64
      for (let i = 0; i < b64.length; i += 50000) {
        const chunk = b64.slice(i, i + 50000);
        await agentExec(key, 'echo -n ' + q(chunk) + ' >> ' + q(tmpB64), 15000);
      }

      // Decodificar + copiar + limpar em UM comando so
      const r = await agentExec(key,
        'base64 -d ' + q(tmpB64) + ' > ' + q(tmpBin) + ' && ' +
        'cp -f ' + q(tmpBin) + ' ' + q(target + f) + ' && ' +
        'chmod 666 ' + q(target + f) + ' && ' +
        'rm -f ' + q(tmpB64) + ' ' + q(tmpBin),
        15000
      );
      logs.push(f + ' injetado');
    }

    res.json({ ok: true, logs });
  } catch (e) {
    logs.push('ERRO: ' + e.message);
    res.json({ ok: false, error: e.message, logs });
  }
});

// ── Agent: Holograma Patch ──
app.post('/api/agent/holo-patch', async (req, res) => {
  const { key, game, mode } = req.body;
  if (!key) return res.status(400).json({ error: 'Key obrigatoria' });
  const agent = agents.get(key);
  if (!agent || !agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return res.status(400).json({ error: 'Agent offline' });

  const g = game === 'max' ? 'max' : 'normal';
  const pkg = g === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const logs = [];

  try {
    // Upload script
    logs.push('Enviando script...');
    const scriptData = fs.readFileSync(HOLO_SCRIPT);
    const b64 = scriptData.toString('base64');
    const remoteScript = '/data/local/tmp/kabe_holo.sh';
    const tmpB64 = '/data/local/tmp/.kabe_holo.b64';

    await agentExec(key, 'rm -f ' + q(tmpB64) + ' ' + q(remoteScript), 15000);

    for (let i = 0; i < b64.length; i += 20000) {
      const chunk = b64.slice(i, i + 20000);
      await agentExec(key, 'echo -n ' + q(chunk) + ' >> ' + q(tmpB64), 15000);
    }

    await agentExec(key,
      'base64 -d ' + q(tmpB64) + ' > ' + q(remoteScript) + ' && ' +
      'chmod 777 ' + q(remoteScript) + ' && ' +
      'rm -f ' + q(tmpB64),
      15000
    );
    logs.push('Script enviado');

    // Executar choice
    const m = parseInt(mode, 10) === 2 ? 2 : 1;
    const isRestore = parseInt(mode, 10) === 3;
    let choice;
    if (g === 'max') {
      choice = isRestore ? 3 : (m === 1 ? 1 : 2);
    } else {
      choice = isRestore ? 6 : (m === 1 ? 4 : 5);
    }

    logs.push('Executando choice ' + choice + '...');
    const r = await agentExec(key, 'sh ' + q(remoteScript) + ' ' + choice, 30000);
    if (r.output) {
      filterHoloLog(r.output).forEach(ln => logs.push(ln));
    }

    await agentExec(key, 'am force-stop ' + pkg, 15000);
    logs.push('Jogo encerrado');
    res.json({ ok: true, logs });
  } catch (e) {
    logs.push('ERRO: ' + e.message);
    res.json({ ok: false, error: e.message, logs });
  }
});

// ── Agent: Holograma Restore ──
app.post('/api/agent/holo-restore', async (req, res) => {
  const { key, game } = req.body;
  if (!key) return res.status(400).json({ error: 'Key obrigatoria' });
  const agent = agents.get(key);
  if (!agent || !agent.lastSeen || (Date.now() - agent.lastSeen) > 15000) return res.status(400).json({ error: 'Agent offline' });
  const g = game === 'max' ? 'max' : 'normal';
  const pkg = g === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const logs = [];
  try {
    const scriptData = fs.readFileSync(HOLO_SCRIPT);
    const b64 = scriptData.toString('base64');
    const remoteScript = '/data/local/tmp/kabe_holo.sh';
    const tmpB64 = '/data/local/tmp/.kabe_holo.b64';
    await agentExec(key, 'rm -f ' + q(tmpB64) + ' ' + q(remoteScript), 15000);
    for (let i = 0; i < b64.length; i += 20000) {
      await agentExec(key, 'echo -n ' + q(b64.slice(i, i + 20000)) + ' >> ' + q(tmpB64), 15000);
    }
    await agentExec(key,
      'base64 -d ' + q(tmpB64) + ' > ' + q(remoteScript) + ' && ' +
      'chmod 777 ' + q(remoteScript) + ' && rm -f ' + q(tmpB64),
      15000
    );
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

// ── Estado SSH ───────────────────────────────────────────
let ssh = null;               // conexão ssh2 atual
let rootMethod = null;        // null | 'direct' | 'su'
let cmdQueue = Promise.resolve(); // serializa comandos (evita sobreposição)

function safeSend(ws, obj) {
  try { if (ws && ws.readyState === 1) ws.send(JSON.stringify(obj)); } catch (e) {}
}

// ── Conectar SSH ─────────────────────────────────────────
function normalizeKey(raw) {
  let k = String(raw || '').trim();
  const m = k.match(/^(-----BEGIN ([^-]+)-----)\s+([A-Za-z0-9+/=\s]+?)\s+(-----END [^-]+-----)$/);
  if (m && k.indexOf('\n') === -1) {
    const body = m[3].replace(/\s+/g, '');
    const lines = body.match(/.{1,64}/g) || [];
    k = m[1] + '\n' + lines.join('\n') + '\n' + m[4];
  }
  return k;
}

function connectSSH(conf) {
  return new Promise((resolve, reject) => {
    if (ssh) { try { ssh.end(); } catch (e) {} ssh = null; }
    ssh = new Client();

    const opts = {
      host: String(conf.host || '127.0.0.1'),
      port: parseInt(conf.port || '22', 10),
      username: String(conf.user || 'root'),
      readyTimeout: 20000,
      keepaliveInterval: 10000,
      keepaliveCountMax: 3
    };

    if (conf.auth === 'key' && conf.key && conf.key.trim()) {
      opts.privateKey = normalizeKey(conf.key);
    } else {
      opts.password = String(conf.pass || '');
    }

    ssh.on('ready', () => resolve());
    ssh.on('error', (err) => reject(new Error('Falha SSH: ' + (err && err.message ? err.message : err))));
    ssh.connect(opts);
  });
}

// ── Executar comando e retornar saída ────────────────────
function execSSH(cmd, ws) {
  return new Promise((resolve, reject) => {
    if (!ssh) return reject(new Error('Sem conexão SSH ativa.'));
    let out = '';
    ssh.exec(cmd, (err, stream) => {
      if (err) return reject(new Error('Erro ao executar: ' + err.message));
      stream.setEncoding('utf8');
      stream.on('close', (code) => resolve({ code, out }));
      stream.on('data', (chunk) => {
        const s = String(chunk);
        out += s;
        safeSend(ws, { type: 'exec_output', line: s });
      });
      stream.stderr.on('data', (chunk) => {
        const s = String(chunk);
        out += s;
        safeSend(ws, { type: 'exec_output', line: s, err: true });
      });
    });
  });
}

// Executa como root quando possível (usa su se necessário)
function execRoot(cmd, ws) {
  if (rootMethod === 'su') {
    return execSSH('su -c ' + JSON.stringify(cmd), ws);
  }
  return execSSH(cmd, ws);
}

// ── Detectar root: direto ou via su ──────────────────────
async function detectRoot(ws) {
  try {
    let r = await execSSH('id -u', ws);
    if (r.out.trim() === '0') { rootMethod = 'direct'; return true; }
    r = await execSSH('su -c \'id -u\'', ws);
    if (r.out.trim() === '0') { rootMethod = 'su'; return true; }
  } catch (e) {}
  rootMethod = null;
  return false;
}

// ── Arquivos HS ─────────────────────────────────────────
const HS_ROOT = path.join(__dirname, '..', 'files', 'hs');
const HS_TARGET_NORMAL = '/data/user/0/com.dts.freefireth/files/contentcache/Compulsory/android/gameassetbundles/';
const HS_TARGET_MAX = '/data/user/0/com.dts.freefiremax/files/contentcache/Compulsory/android/gameassetbundles/';
const HS_CACHE_FILE = 'cache_res.~2BrPJlgpDAnfyUCp~2Biox5bwsZlQQ~3D';

function hsTarget(game) {
  return game === 'max' ? HS_TARGET_MAX : HS_TARGET_NORMAL;
}

const HS_MODES = {
  limpo: {
    label: 'Limpo',
    desc: 'Sem HS, jogo original',
    files: [HS_CACHE_FILE]
  },
  hsalto: {
    label: 'HS Alto',
    desc: 'Capa acima da cabeca',
    files: [HS_CACHE_FILE]
  },
  hsaltoplus: {
    label: 'HS Alto+',
    desc: 'Capa acima e dos lados da cabeca',
    files: [HS_CACHE_FILE]
  },
  hsneck: {
    label: 'HS Pescoco',
    desc: 'Capa no pescoco',
    files: [HS_CACHE_FILE]
  },
  hspeito: {
    label: 'HS Peito',
    desc: 'Capa no peito',
    files: [HS_CACHE_FILE]
  }
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

// Injeta via base64 (shell)
async function injectHSB64(modeId, game, ws) {
  const m = HS_MODES[modeId];
  if (!m) return Promise.reject(new Error('Modo HS invalido: ' + modeId));

  const target = hsTarget(game);
  const pkg = game === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const cmds = [];
  for (const f of m.files) {
    const local = path.join(HS_ROOT, modeId, f);
    if (!fs.existsSync(local)) return Promise.reject(new Error('Arquivo local nao encontrado: ' + f));
    cmds.push({ local, remote: target + f, name: f });
  }

  await execRoot("mkdir -p '" + target + "'", ws);

  for (const c of cmds) {
    const data = fs.readFileSync(c.local);
    const b64 = data.toString('base64');
    const chunkSize = 20000;
    const tmpB64 = '/data/local/tmp/.kabe_hs.b64';
    const tmpBin = '/data/local/tmp/.kabe_hs.bin';

    await execRoot("rm -f '" + tmpB64 + "' '" + tmpBin + "'", ws);
    await execRoot("touch '" + c.remote + "' && chmod 666 '" + c.remote + "'", ws);

    for (let i = 0; i < b64.length; i += chunkSize) {
      const chunk = b64.slice(i, i + chunkSize);
      await execRoot("su -c 'echo -n \"" + chunk.replace(/"/g, '\\"') + "\" >> \"" + tmpB64 + "\"'", ws);
    }

    await execRoot(
      "su -c 'base64 -d \"" + tmpB64 + "\" > \"" + tmpBin + "\" && " +
      "cp -f \"" + tmpBin + "\" \"" + c.remote + "\" && " +
      "rm -f \"" + tmpB64 + "\" \"" + tmpBin + "\"'",
      ws
    );
    await execRoot(
      "chmod 666 '" + c.remote + "'; " +
      "U=$(stat -c '%u:%g' '/data/user/0/" + pkg + "' 2>/dev/null); " +
      "[ -n \"$U\" ] && chown \"$U\" '" + c.remote + "' 2>/dev/null; " +
      "chown vold:everybody '" + c.remote + "' 2>/dev/null; true",
      ws
    ).catch(() => {});
  }
  return cmds.length;
}

// ── Holograma (KabeWall_Holo via base64) ────────────────
const HOLO_SCRIPT = path.join(__dirname, '..', 'files', 'kabe_holo.sh');
const HOLO_WRAP = path.join(__dirname, '..', 'files', 'kabe_holo_wrap.sh');

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

function holoBak(game) {
  return HOLO.bakDir + '/' + HOLO.fileName + (game === 'max' ? '_max.bak' : '_reg.bak');
}

// q() já definido acima

// Upload via base64 com permissao 777
async function uploadScript(localPath, remotePath, ws) {
  if (!fs.existsSync(localPath)) {
    throw new Error('Script nao encontrado: ' + localPath);
  }
  const data = fs.readFileSync(localPath);
  const b64 = data.toString('base64');
  const chunkSize = 24000;

  await execRoot('rm -f ' + q(remotePath) + ' && touch ' + q(remotePath) + ' && chmod 666 ' + q(remotePath), ws);

  for (let i = 0; i < b64.length; i += chunkSize) {
    const chunk = b64.slice(i, i + chunkSize);
    await execRoot('printf %s ' + q(chunk) + ' >> ' + q(remotePath), ws);
  }

  await execRoot(
    'base64 -d ' + q(remotePath) + ' > ' + q(remotePath + '.tmp') +
    ' && mv -f ' + q(remotePath + '.tmp') + ' ' + q(remotePath) +
    ' && chmod 777 ' + q(remotePath),
    ws
  );
  return remotePath;
}

// ── Hash scan ─────────────────────────────────────────────
async function holoScanHashes(pth, ws) {
  const r = await execRoot(
    'grep -a -o "assets/bin/Data/[0-9a-f]*" ' + q(pth) + ' 2>/dev/null' +
    ' | sed "s|assets/bin/Data/||" | sort -u', ws
  );
  const all = (r.out || '').split('\n').filter(s => /^[0-9a-f]{32}$/.test(s));
  return { all, set: new Set(all), count: all.length };
}

// ── Patch direto (sem Kurama) ──────────────────────────────
async function holoPatch(game, mode, ws) {
  const pkg = game === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const pth = holoPath(game);
  const bak = holoBak(game);
  const logs = [];

  // Garantir backup
  await execRoot('mkdir -p ' + q(HOLO.bakDir), ws);
  const bakExists = await execRoot('[ -f ' + q(bak) + ' ] && echo Y || echo N', ws);
  if (bakExists.out.trim() === 'N') {
    const cpR = await execRoot('cp ' + q(pth) + ' ' + q(bak) + ' 2>&1', ws);
    if (cpR.out.trim()) logs.push('Backup: ' + cpR.out.trim());
    else logs.push('Backup criado.');
  }

  // Verificar arquivo
  const fExists = await execRoot('[ -f ' + q(pth) + ' ] && echo Y || echo N', ws);
  if (fExists.out.trim() !== 'Y') {
    return 'ERRO: Arquivo nao encontrado em ' + pth;
  }

  // Scan de hashes
  const scan = await holoScanHashes(pth, ws);
  logs.push('Assets encontrados: ' + scan.count);

  const isHolo = mode === 1;
  const pairs = isHolo
    ? [{ o: HOLO.o1, n: HOLO.n1 }]
    : [{ o: HOLO.og, n: HOLO.ng }];

  let patched = false;
  for (const p of pairs) {
    if (scan.set.has(p.o)) {
      await execRoot('sed -i "s/' + p.o + '/' + p.n + '/g" ' + q(pth), ws);
      logs.push('OK: ' + p.o.slice(0, 8) + '... -> ' + p.n.slice(0, 8) + '...');
      patched = true;
      break;
    }
  }

  if (!patched) {
    const alreadyPatched = pairs.some(p => scan.set.has(p.n));
    if (alreadyPatched) {
      logs.push('JA APLICADO (hash injetado ja presente, original ausente).');
    } else {
      logs.push('FALHA: hash original nao encontrado no arquivo.');
      logs.push('O Kurama esta desatualizado para esta versao do jogo.');
      logs.push('Hashes no arquivo (primeiros 20):');
      logs.push(scan.all.slice(0, 20).join(', '));
      if (scan.count > 20) logs.push('... mais ' + (scan.count - 20));
    }
  }

  await execRoot('am force-stop ' + pkg, ws);
  logs.push('Jogo encerrado.');
  return logs.join('\n');
}

// ── Patch via .sh (KabeWall_Holo) ────────────────────────
async function holoPatchScript(game, mode, ws) {
  const pkg = game === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const logs = [];

  // Upload script
  const remoteScript = '/data/local/tmp/kabe_holo.sh';
  logs.push('Enviando script...');
  await uploadScript(HOLO_SCRIPT, remoteScript, ws);

  // Mapear game+mode -> choice
  const isHolo = mode === 1;
  const isRestore = mode === 3;
  let choice;
  if (game === 'max') {
    choice = isRestore ? 3 : (isHolo ? 1 : 2);
  } else {
    choice = isRestore ? 6 : (isHolo ? 4 : 5);
  }

  logs.push('Executando choice ' + choice + '...');

  // Executa direto com argumento (sem wrapper, sem pipe)
  const cmd = 'sh ' + q(remoteScript) + ' ' + choice + ' 2>&1';
  const r = await execRoot(cmd, ws);

  if (r.out && r.out.trim()) {
    r.out.split(/\r?\n/).forEach(function(ln) { if (ln.trim()) logs.push(ln.trim()); });
  }

  // Scan resultado
  const pth = holoPath(game);
  const scan = await holoScanHashes(pth, ws);
  logs.push('Assets: ' + scan.count);
  logs.push('O1: ' + (scan.set.has(HOLO.o1) ? 'PRESENTE' : 'AUSENTE'));
  logs.push('N1: ' + (scan.set.has(HOLO.n1) ? 'PRESENTE' : 'AUSENTE'));

  await execRoot('am force-stop ' + pkg, ws);
  logs.push('Jogo encerrado.');
  return logs.join('\n');
}

// ── Restore via .sh ───────────────────────────────────────
async function holoRestoreScript(game, ws) {
  return holoPatchScript(game, 3, ws);
}

// ── Restore direto ─────────────────────────────────────────
async function holoRestore(game, ws) {
  const pkg = game === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const pth = holoPath(game);
  const bak = holoBak(game);
  const logs = [];

  const bakExists = await execRoot('[ -f ' + q(bak) + ' ] && echo Y || echo N', ws);
  if (bakExists.out.trim() === 'Y') {
    await execRoot('cp ' + q(bak) + ' ' + q(pth), ws);
    logs.push('Restaurado do backup.');
  } else {
    // Fallback: sed reverso
    const scan = await holoScanHashes(pth, ws);
    let reverted = false;
    if (scan.set.has(HOLO.n1)) {
      await execRoot('sed -i "s/' + HOLO.n1 + '/' + HOLO.o1 + '/g" ' + q(pth), ws);
      logs.push('Revertido N1 -> O1.');
      reverted = true;
    }
    if (scan.set.has(HOLO.ng)) {
      await execRoot('sed -i "s/' + HOLO.ng + '/' + HOLO.og + '/g" ' + q(pth), ws);
      logs.push('Revertido NG -> OG.');
      reverted = true;
    }
    if (!reverted) logs.push('Nada para reverter (sem backup, hashes nao encontrados).');
  }

  await execRoot('am force-stop ' + pkg, ws);
  logs.push('Jogo encerrado.');
  return logs.join('\n');
}

// ── Diagnostico completo ───────────────────────────────────
async function holoDiag(game, ws) {
  const pkg = game === 'max' ? 'com.dts.freefiremax' : 'com.dts.freefireth';
  const pth = holoPath(game);
  const bak = holoBak(game);
  const logs = [];

  // Info do pacote
  const pmR = await execRoot('pm path ' + pkg + ' 2>&1 | head -1', ws);
  logs.push('Pacote: ' + (pmR.out || 'nao encontrado').trim());

  // Info do arquivo
  const fR = await execRoot('ls -l ' + q(pth) + ' 2>&1', ws);
  logs.push('Arquivo: ' + (fR.out || 'nao encontrado').trim());

  // Info do backup
  const bR = await execRoot('ls -l ' + q(bak) + ' 2>&1', ws);
  logs.push('Backup: ' + (bR.out || 'nao encontrado').trim());

  // Scan de hashes
  const scan = await holoScanHashes(pth, ws);
  logs.push('Assets: ' + scan.count);

  // Verificar pares conhecidos
  const checks = [
    ['O1 (holo orig)', HOLO.o1],
    ['N1 (holo inj)', HOLO.n1],
    ['OG (gloo orig)', HOLO.og],
    ['NG (gloo inj)', HOLO.ng],
  ];
  for (const [label, hash] of checks) {
    logs.push(label + ': ' + (scan.set.has(hash) ? 'PRESENTE' : 'AUSENTE'));
  }

  // Listar hashes
  logs.push('--- Hashes (ate 40) ---');
  for (const h of scan.all.slice(0, 40)) {
    logs.push('  ' + h);
  }
  if (scan.count > 40) logs.push('  ... mais ' + (scan.count - 40));

  return logs.join('\n');
}

// ── Protocolo WebSocket ──────────────────────────────────
wss.on('connection', (ws) => {
  safeSend(ws, { type: 'engine_status', mode: 'live', ssh: false });
  safeSend(ws, { type: 'hs_list', modes: hsModeList(), target: HS_TARGET_NORMAL });

  ws.on('message', async (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch (e) { return; }

    if (msg.type === 'ssh_connect') {
      try {
        await connectSSH(msg.data);
        safeSend(ws, { type: 'ssh_status', status: 'connected' });
        safeSend(ws, { type: 'engine_status', mode: 'live', ssh: true });
        cmdQueue = cmdQueue.then(async () => {
          try {
            const ok = await detectRoot(ws);
            safeSend(ws, { type: 'exec_done', root: ok, code: 0 });
          } catch (e) {
            safeSend(ws, { type: 'exec_done', error: String(e.message || e) });
          }
        });
      } catch (e) {
        safeSend(ws, { type: 'ssh_status', status: 'error', msg: String(e.message || e) });
        safeSend(ws, { type: 'engine_status', mode: 'live', ssh: false });
      }
    }

    else if (msg.type === 'ssh_disconnect') {
      if (ssh) { try { ssh.end(); } catch (e) {} ssh = null; }
      rootMethod = null;
      safeSend(ws, { type: 'ssh_status', status: 'disconnected' });
      safeSend(ws, { type: 'engine_status', mode: 'live', ssh: false });
    }

    else if (msg.type === 'exec' && msg.data && msg.data.cmd) {
      safeSend(ws, { type: 'exec_start' });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const r = await execRoot(msg.data.cmd, ws);
          safeSend(ws, { type: 'exec_done', code: r.code, out: r.out });
        } catch (e) {
          safeSend(ws, { type: 'exec_done', error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'hs_inject' && msg.data && msg.data.mode) {
      safeSend(ws, { type: 'hs_start', mode: msg.data.mode });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const n = await injectHSB64(msg.data.mode, ws);
          safeSend(ws, { type: 'hs_done', mode: msg.data.mode, ok: true, files: n });
        } catch (e) {
          safeSend(ws, { type: 'hs_done', mode: msg.data.mode, ok: false, error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'hs_inject_b64' && msg.data && msg.data.mode) {
      const game = msg.data.game === 'max' ? 'max' : 'normal';
      safeSend(ws, { type: 'hs_start', mode: msg.data.mode });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const n = await injectHSB64(msg.data.mode, game, ws);
          safeSend(ws, { type: 'hs_done', mode: msg.data.mode, ok: true, files: n });
        } catch (e) {
          safeSend(ws, { type: 'hs_done', mode: msg.data.mode, ok: false, error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'holo_patch' && msg.data) {
      const game = msg.data.game === 'max' ? 'max' : 'normal';
      const mode = parseInt(msg.data.mode, 10) === 2 ? 2 : 1;
      safeSend(ws, { type: 'holo_start', action: 'patch', game, mode });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const out = await holoPatchScript(game, mode, ws);
          safeSend(ws, { type: 'holo_done', ok: true, action: 'patch', game, mode, out });
        } catch (e) {
          safeSend(ws, { type: 'holo_done', ok: false, action: 'patch', error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'holo_restore' && msg.data) {
      const game = msg.data.game === 'max' ? 'max' : 'normal';
      safeSend(ws, { type: 'holo_start', action: 'restore', game });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const out = await holoRestoreScript(game, ws);
          safeSend(ws, { type: 'holo_done', ok: true, action: 'restore', game, out });
        } catch (e) {
          safeSend(ws, { type: 'holo_done', ok: false, action: 'restore', error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'holo_diag' && msg.data) {
      const game = msg.data.game === 'max' ? 'max' : 'normal';
      safeSend(ws, { type: 'holo_start', action: 'diag', game });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const out = await holoDiag(game, ws);
          safeSend(ws, { type: 'holo_done', ok: true, action: 'diag', out });
        } catch (e) {
          safeSend(ws, { type: 'holo_done', ok: false, action: 'diag', error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'holo_scan' && msg.data) {
      const game = msg.data.game === 'max' ? 'max' : 'normal';
      safeSend(ws, { type: 'holo_start', action: 'scan', game });
      cmdQueue = cmdQueue.then(async () => {
        try {
          const pth = holoPath(game);
          const scan = await holoScanHashes(pth, ws);
          const known = {
            o1: { hash: HOLO.o1, label: 'Holograma orig', present: scan.set.has(HOLO.o1) },
            n1: { hash: HOLO.n1, label: 'Holograma inj', present: scan.set.has(HOLO.n1) },
            og: { hash: HOLO.og, label: 'Gloo orig', present: scan.set.has(HOLO.og) },
            ng: { hash: HOLO.ng, label: 'Gloo inj', present: scan.set.has(HOLO.ng) },
          };
          safeSend(ws, {
            type: 'holo_done', ok: true, action: 'scan',
            out: JSON.stringify({ count: scan.count, known, hashes: scan.all.slice(0, 100) })
          });
        } catch (e) {
          safeSend(ws, { type: 'holo_done', ok: false, action: 'scan', error: String(e.message || e) });
        }
      });
    }

    else if (msg.type === 'game_stop') {
      const pkg = (msg.data && msg.data.pkg) || 'com.dts.freefireth';
      safeSend(ws, { type: 'hs_line', line: 'Encerrando ' + pkg + '...' });
      cmdQueue = cmdQueue.then(async () => {
        try {
          await execRoot('am force-stop ' + pkg, ws);
          safeSend(ws, { type: 'game_stop_done', pkg, ok: true });
        } catch (e) {
          safeSend(ws, { type: 'game_stop_done', pkg, ok: false, error: String(e.message || e) });
        }
      });
    }
  });

  ws.on('close', () => {});
});

server.listen(PORT, () => {
  console.log('──────────────────────────────────────────────');
  console.log('  KABE PRIVATE — servidor local rodando');
  console.log('  Abra:  http://localhost:' + PORT);
  console.log('──────────────────────────────────────────────');
});
