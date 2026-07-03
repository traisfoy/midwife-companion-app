import { Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { useAuth } from './auth.jsx';
import { resetSocket } from './socket.js';
import Login from './pages/Login.jsx';
import PatientHome from './pages/patient/PatientHome.jsx';
import Dashboard from './pages/midwife/Dashboard.jsx';
import PatientDetail from './pages/midwife/PatientDetail.jsx';

function RequireRole({ role, children }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" replace />;
  if (user.role !== role) {
    return <Navigate to={user.role === 'midwife' ? '/midwife' : '/patient'} replace />;
  }
  return children;
}

function Shell({ children }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  return (
    <div className="app-shell">
      <div className="topbar">
        <h1>Midwife Companion</h1>
        {user && (
          <span className="who">
            {user.name} ({user.role}){' '}
            <button
              className="btn-ghost"
              onClick={() => {
                resetSocket();
                logout();
                navigate('/login');
              }}
            >
              Log out
            </button>
          </span>
        )}
      </div>
      {children}
    </div>
  );
}

export default function App() {
  const { user } = useAuth();
  return (
    <Shell>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/patient"
          element={
            <RequireRole role="patient">
              <PatientHome />
            </RequireRole>
          }
        />
        <Route
          path="/midwife"
          element={
            <RequireRole role="midwife">
              <Dashboard />
            </RequireRole>
          }
        />
        <Route
          path="/midwife/patients/:id"
          element={
            <RequireRole role="midwife">
              <PatientDetail />
            </RequireRole>
          }
        />
        <Route
          path="*"
          element={
            <Navigate
              to={!user ? '/login' : user.role === 'midwife' ? '/midwife' : '/patient'}
              replace
            />
          }
        />
      </Routes>
    </Shell>
  );
}
