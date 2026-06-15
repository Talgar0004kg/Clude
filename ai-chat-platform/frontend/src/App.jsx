import { Routes, Route, Navigate } from 'react-router-dom'
import { auth } from './api/client'
import Navbar from './components/Navbar'
import Landing from './pages/Landing'
import Demo from './pages/Demo'
import Chat from './pages/Chat'
import Login from './pages/Login'
import Register from './pages/Register'
import Dashboard from './pages/dashboard/Dashboard'
import AdminPanel from './pages/admin/AdminPanel'

function Protected({ role, children }) {
  const user = auth.current()
  if (!user) return <Navigate to="/login" replace />
  if (role && user.role !== role) return <Navigate to="/" replace />
  return children
}

// Чат-страница идёт без общего навбара (это страница для клиента бизнеса)
function WithNav({ children }) {
  return (
    <>
      <Navbar />
      {children}
    </>
  )
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<WithNav><Landing /></WithNav>} />
      <Route path="/demo" element={<WithNav><Demo /></WithNav>} />
      <Route path="/login" element={<WithNav><Login /></WithNav>} />
      <Route path="/register" element={<WithNav><Register /></WithNav>} />

      {/* Публичный чат бизнеса по уникальной ссылке */}
      <Route path="/c/:slug" element={<Chat />} />

      {/* Кабинет бизнеса */}
      <Route
        path="/dashboard/*"
        element={
          <Protected role="business">
            <WithNav><Dashboard /></WithNav>
          </Protected>
        }
      />

      {/* Админ-панель */}
      <Route
        path="/admin"
        element={
          <Protected role="admin">
            <WithNav><AdminPanel /></WithNav>
          </Protected>
        }
      />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
