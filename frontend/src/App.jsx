import { useEffect, useState } from 'react';

// All API calls use a relative path. In production, Nginx on the
// presentation-tier EC2 reverse-proxies /api/* to the application
// tier. In `vite dev`, vite.config.js proxies /api locally.
const API_BASE = '/api';

export default function App() {
  const [notes, setNotes] = useState([]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [health, setHealth] = useState(null);

  async function loadNotes() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/notes`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setNotes(await res.json());
    } catch (e) {
      setError(`Could not fetch notes: ${e.message}`);
    } finally {
      setLoading(false);
    }
  }

  async function checkHealth() {
    try {
      const res = await fetch(`${API_BASE}/health`);
      const data = await res.json();
      setHealth(data);
    } catch (e) {
      setHealth({ status: 'error', message: e.message });
    }
  }

  useEffect(() => {
    loadNotes();
    checkHealth();
  }, []);

  async function addNote(e) {
    e.preventDefault();
    if (!title.trim()) return;
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/notes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, body }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setTitle('');
      setBody('');
      await loadNotes();
    } catch (e) {
      setError(`Could not save note: ${e.message}`);
    }
  }

  async function deleteNote(id) {
    if (!confirm('Delete this note?')) return;
    try {
      const res = await fetch(`${API_BASE}/notes/${id}`, { method: 'DELETE' });
      if (!res.ok && res.status !== 204) throw new Error(`HTTP ${res.status}`);
      await loadNotes();
    } catch (e) {
      setError(`Could not delete note: ${e.message}`);
    }
  }

  return (
    <div className="container">
      <header>
        <h1>📝 3-Tier Notes</h1>
        <p className="subtitle">
          Presentation (Nginx + React) → Application (Express) → Data (PostgreSQL)
        </p>
        <div className={`health ${health?.status === 'ok' ? 'ok' : 'bad'}`}>
          {health
            ? health.status === 'ok'
              ? `API healthy · DB time: ${new Date(health.db_time).toLocaleString()}`
              : `API unhealthy: ${health.message}`
            : 'Checking API…'}
        </div>
      </header>

      <form onSubmit={addNote} className="card">
        <h2>Add a note</h2>
        <input
          type="text"
          placeholder="Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          required
        />
        <textarea
          placeholder="Body (optional)"
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={3}
        />
        <button type="submit">Save note</button>
      </form>

      {error && <div className="error">{error}</div>}

      <section className="card">
        <h2>All notes ({notes.length})</h2>
        {loading ? (
          <p>Loading…</p>
        ) : notes.length === 0 ? (
          <p className="muted">No notes yet. Add one above.</p>
        ) : (
          <ul className="notes">
            {notes.map((n) => (
              <li key={n.id}>
                <div className="note-head">
                  <strong>{n.title}</strong>
                  <button className="del" onClick={() => deleteNote(n.id)}>
                    Delete
                  </button>
                </div>
                {n.body && <p>{n.body}</p>}
                <small className="muted">
                  #{n.id} · {new Date(n.created_at).toLocaleString()}
                </small>
              </li>
            ))}
          </ul>
        )}
      </section>

      <footer>
        <small className="muted">3-Tier Application on AWS EC2 — Module 4 Assignment</small>
      </footer>
    </div>
  );
}
