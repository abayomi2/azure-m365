const express = require('express');
const { v4: uuidv4 } = require('uuid');
const app = express();
app.use(express.json());

const tickets = new Map();

app.get('/healthz', (req, res) => res.status(200).send('ok'));

app.post('/api/tickets', (req, res) => {
  const id = uuidv4();
  const { title, severity, tenant } = req.body;
  const ticket = { id, title, severity: severity || 'P3', tenant: tenant || 'internal', status: 'New', createdAt: new Date().toISOString() };
  tickets.set(id, ticket);
  res.status(201).json(ticket);
});

app.get('/api/tickets/:id', (req, res) => {
  const t = tickets.get(req.params.id);
  if (!t) return res.status(404).send({ error: 'Not found' });
  res.json(t);
});

app.get('/api/tickets', (req, res) => res.json([...tickets.values()]));

app.listen(8080, () => console.log('ISH API listening on 8080'));
