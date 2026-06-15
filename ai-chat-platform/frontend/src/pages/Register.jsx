import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useT } from '../i18n'
import { auth } from '../api/client'

export default function Register() {
  const { t } = useT()
  const navigate = useNavigate()
  const [form, setForm] = useState({ businessName: '', email: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await auth.register(form)
      navigate('/dashboard')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="auth-page">
      <form className="card auth-card" onSubmit={submit}>
        <h1>{t('auth.register.title')}</h1>
        <div className="field">
          <label className="label">{t('auth.businessName')}</label>
          <input className="input" value={form.businessName} required onChange={(e) => setForm({ ...form, businessName: e.target.value })} />
        </div>
        <div className="field">
          <label className="label">{t('auth.email')}</label>
          <input className="input" type="email" value={form.email} required onChange={(e) => setForm({ ...form, email: e.target.value })} />
        </div>
        <div className="field">
          <label className="label">{t('auth.password')}</label>
          <input className="input" type="password" value={form.password} required onChange={(e) => setForm({ ...form, password: e.target.value })} />
        </div>
        {error && <p className="auth-error">{error}</p>}
        <button className="btn btn-primary btn-block" disabled={loading}>
          {loading ? t('common.loading') : t('auth.registerBtn')}
        </button>
        <Link to="/login" className="auth-link">{t('auth.haveAccount')}</Link>
      </form>
    </main>
  )
}
