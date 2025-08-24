const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// Static files
app.use(express.static(path.join(__dirname, 'public')));

// Health check
app.get('/healthz', (_req, res) => res.status(200).send('ok'));

// Simple API for metadata (optional; used by the page footer)
app.get('/meta', (_req, res) => {
  res.json({
    env: process.env.NODE_ENV || 'dev',
    app: 'ISH DevOps Project Dashboard',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Serve SPA
app.get('*', (_req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => console.log(`Dashboard running on :${PORT}`));
