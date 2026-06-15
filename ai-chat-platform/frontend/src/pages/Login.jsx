import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useT } from '../i18n'
import { auth } from '../api/client'

export default function Login() {
  const { t } = useT()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const { user } = await auth.login(email, password)
      navigate(user.role === 'admin' ? '/admin' : '/dashboard')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="auth-page">
      <form className="card auth-card" onSubmit={submit}>
        <h1>{t('auth.login.title')}</h1>
        <div className="field">
          <label className="label">{t('auth.email')}</label>
          <input className="input" type="email" value={email} required onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label className="label">{t('auth.password')}</label>
          <input className="input" type="password" value={password} required onChange={(e) => setPassword(e.target.value)} />
        </div>
        {error && <p className="auth-error">{error}</p>}
        <button className="btn btn-primary btn-block" disabled={loading}>
          {loading ? t('common.loading') : t('auth.loginBtn')}
        </button>
        <p className="hint" style={{ marginTop: 14 }}>{t('auth.demoHint')}</p>
        <Link to="/register" className="auth-link">{t('auth.noAccount')}</Link>
      </form>
    </main>
  )
}
