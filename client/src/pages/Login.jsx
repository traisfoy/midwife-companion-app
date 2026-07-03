import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { resetSocket } from '../socket.js';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      resetSocket();
      const user = await login(email, password);
      navigate(user.role === 'midwife' ? '/midwife' : '/patient');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card login-box">
      <h2>Sign in</h2>
      <form onSubmit={submit}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
        {error && <div className="error">{error}</div>}
        <button className="btn btn-primary" disabled={busy} style={{ width: '100%' }}>
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
      <p className="hint" style={{ marginTop: 14 }}>
        Demo accounts — midwife: <code>sarah@peacefulbeginnings.test</code> /{' '}
        <code>midwife123</code>
        <br />
        patients: <code>maria@example.test</code>, <code>jasmine@example.test</code>,{' '}
        <code>emily@example.test</code> / <code>patient123</code>
      </p>
    </div>
  );
}
