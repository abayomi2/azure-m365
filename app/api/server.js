const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8080;

// --- Application Insights (only if connection string is set) ---
try {
  if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    const appInsights = require('applicationinsights');
    appInsights
      .setup() // reads APPLICATIONINSIGHTS_CONNECTION_STRING env var
      .setAutoCollectRequests(true)
      .setAutoCollectDependencies(true)
      .setSendLiveMetrics(false)
      .setAutoCollectExceptions(true)
      .start();
    console.log("Application Insights initialized");
  } else {
    console.log("AI connection string not set; skipping AI init");
  }
} catch (e) {
  console.log("AI init error:", e.message);
}

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
