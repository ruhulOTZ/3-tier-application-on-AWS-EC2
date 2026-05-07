// Application Tier - Express REST API for Notes
// Connects to the Data Tier (PostgreSQL on EC2 #3)
// Consumed by the Presentation Tier (Nginx on EC2 #1)

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3001;

// --- Database connection pool ---
const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

pool.on('error', (err) => {
  console.error('Unexpected DB pool error:', err);
});

// --- Middleware ---
app.use(cors()); // safe to enable; in prod Nginx proxies /api so this is mostly belt-and-suspenders
app.use(express.json());

// Tiny request logger
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// --- Routes ---

// Liveness probe
app.get('/api/health', async (_req, res) => {
  try {
    const r = await pool.query('SELECT NOW() AS now');
    res.json({ status: 'ok', db_time: r.rows[0].now });
  } catch (err) {
    console.error('Health DB check failed:', err.message);
    res.status(500).json({ status: 'error', message: 'DB not reachable' });
  }
});

// List all notes (newest first)
app.get('/api/notes', async (_req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, title, body, created_at FROM notes ORDER BY created_at DESC'
    );
    res.json(r.rows);
  } catch (err) {
    console.error('GET /api/notes failed:', err.message);
    res.status(500).json({ error: 'Failed to fetch notes' });
  }
});

// Create a note
app.post('/api/notes', async (req, res) => {
  const { title, body } = req.body || {};
  if (!title || typeof title !== 'string') {
    return res.status(400).json({ error: 'title is required' });
  }
  try {
    const r = await pool.query(
      'INSERT INTO notes (title, body) VALUES ($1, $2) RETURNING id, title, body, created_at',
      [title.trim(), (body || '').trim()]
    );
    res.status(201).json(r.rows[0]);
  } catch (err) {
    console.error('POST /api/notes failed:', err.message);
    res.status(500).json({ error: 'Failed to create note' });
  }
});

// Delete a note
app.delete('/api/notes/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) {
    return res.status(400).json({ error: 'invalid id' });
  }
  try {
    const r = await pool.query('DELETE FROM notes WHERE id = $1', [id]);
    if (r.rowCount === 0) return res.status(404).json({ error: 'not found' });
    res.status(204).send();
  } catch (err) {
    console.error('DELETE /api/notes/:id failed:', err.message);
    res.status(500).json({ error: 'Failed to delete note' });
  }
});

// Root
app.get('/', (_req, res) => {
  res.send('Notes API - Application Tier. Try GET /api/health');
});

// --- Start ---
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Notes API listening on 0.0.0.0:${PORT}`);
  console.log(`DB target: ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}`);
});
