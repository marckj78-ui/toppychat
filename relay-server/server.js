// ToppyChat relay server
//
// Scopo: fare da "postino" in tempo reale tra due o piu' telefoni che usano
// l'app ToppyChat. Non salva MAI i messaggi su disco: tutto vive solo in
// memoria (RAM) del processo e sparisce al riavvio del server. Se il
// destinatario e' online il messaggio viene inoltrato subito; se e' offline
// viene tenuto in una piccola coda in memoria (con limiti) finche' non si
// riconnette, oppure scartato dopo un tempo massimo.
//
// Il salvataggio "vero" delle conversazioni avviene solo sui telefoni, in
// locale, come file di testo in Download/ToppyChat/ (vedi la app Flutter).

const http = require('http');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 8080;
const RELAY_TOKEN = process.env.RELAY_TOKEN || '';

// Quanti messaggi tenere in coda al massimo per un numero offline.
const MAX_QUEUE_PER_PHONE = 200;
// Dopo quanto tempo (ms) un messaggio in coda viene scartato se il
// destinatario non si e' mai riconnesso. Default: 24 ore.
const MAX_QUEUE_AGE_MS = 24 * 60 * 60 * 1000;

if (!RELAY_TOKEN) {
  console.warn(
    '[avviso] RELAY_TOKEN non impostato: chiunque conosca l\'indirizzo del server potra\' collegarsi. ' +
    'Imposta la variabile d\'ambiente RELAY_TOKEN prima di usare il server sul serio.'
  );
}

// phone (string) -> WebSocket connesso in questo momento
const connected = new Map();
// phone (string) -> array di messaggi in attesa { from, text, id, ts, queuedAt }
const queues = new Map();

function normalizePhone(phone) {
  return String(phone || '').trim();
}

function send(ws, payload) {
  if (ws && ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function queueMessage(toPhone, message) {
  let q = queues.get(toPhone);
  if (!q) {
    q = [];
    queues.set(toPhone, q);
  }
  q.push({ ...message, queuedAt: Date.now() });
  if (q.length > MAX_QUEUE_PER_PHONE) {
    q.shift(); // scarta il piu' vecchio, restiamo leggeri
  }
}

function flushQueue(phone, ws) {
  const q = queues.get(phone);
  if (!q || q.length === 0) return;
  const now = Date.now();
  for (const msg of q) {
    if (now - msg.queuedAt <= MAX_QUEUE_AGE_MS) {
      send(ws, { type: 'message', from: msg.from, text: msg.text, id: msg.id, ts: msg.ts });
    }
  }
  queues.delete(phone);
}

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      connected: connected.size,
      queuedPhones: queues.size,
    }));
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('ToppyChat relay attivo. Nessun messaggio viene salvato su disco.');
});

const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
  let registeredPhone = null;

  ws.on('message', (raw) => {
    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch (err) {
      send(ws, { type: 'error', message: 'JSON non valido' });
      return;
    }

    if (data.type === 'register') {
      if (RELAY_TOKEN && data.token !== RELAY_TOKEN) {
        send(ws, { type: 'error', message: 'Token non valido' });
        ws.close();
        return;
      }
      const phone = normalizePhone(data.phone);
      if (!phone) {
        send(ws, { type: 'error', message: 'Numero di telefono mancante' });
        return;
      }
      registeredPhone = phone;
      connected.set(phone, ws);
      send(ws, { type: 'registered', phone });
      flushQueue(phone, ws);
      return;
    }

    if (data.type === 'message') {
      if (!registeredPhone) {
        send(ws, { type: 'error', message: 'Devi registrarti prima di inviare messaggi' });
        return;
      }
      const to = normalizePhone(data.to);
      const text = String(data.text || '');
      const id = String(data.id || '');
      const ts = Number(data.ts) || Date.now();
      if (!to || !text) {
        send(ws, { type: 'error', message: 'Destinatario o testo mancante' });
        return;
      }

      const payload = { from: registeredPhone, text, id, ts };
      const recipientWs = connected.get(to);
      if (recipientWs && recipientWs.readyState === recipientWs.OPEN) {
        send(recipientWs, { type: 'message', ...payload });
        send(ws, { type: 'ack', id, delivered: true });
      } else {
        queueMessage(to, payload);
        send(ws, { type: 'ack', id, delivered: false, queued: true });
      }
      return;
    }

    if (data.type === 'ping') {
      send(ws, { type: 'pong' });
      return;
    }

    send(ws, { type: 'error', message: `Tipo messaggio sconosciuto: ${data.type}` });
  });

  ws.on('close', () => {
    if (registeredPhone && connected.get(registeredPhone) === ws) {
      connected.delete(registeredPhone);
    }
  });
});

server.listen(PORT, () => {
  console.log(`ToppyChat relay in ascolto sulla porta ${PORT} (zero persistenza su disco).`);
});
