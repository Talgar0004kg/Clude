import { Link, useNavigate, useLocation } from 'react-router-dom'
import { useT } from '../i18n'
import { auth } from '../api/client'
import LanguageSwitcher from './LanguageSwitcher'

export default function Navbar() {
  const { t } = useT()
  const navigate = useNavigate()
  const location = useLocation()
  const user = auth.current()

  const logout = () => {
    auth.logout()
    navigate('/')
  }

  return (
    <header className="navbar">
      <div className="container navbar-inner">
        <Link to="/" className="brand">
          <span className="brand-mark">💬</span>
          <span className="brand-name">{t('app.name')}</span>
        </Link>

        <nav className="navbar-links">
          {location.pathname === '/' && (
            <>
              <a href="#features">{t('nav.features')}</a>
              <a href="#how">{t('nav.howItWorks')}</a>
            </>
          )}
          <Link to="/demo">{t('nav.demo')}</Link>
        </nav>

        <div className="navbar-actions">
          <LanguageSwitcher />
          {!user && (
            <>
              <Link to="/login" className="btn btn-ghost btn-sm">{t('nav.login')}</Link>
              <Link to="/register" className="btn btn-primary btn-sm">{t('nav.register')}</Link>
            </>
          )}
          {user?.role === 'business' && (
            <>
              <Link to="/dashboard" className="btn btn-ghost btn-sm">{t('nav.dashboard')}</Link>
              <button className="btn btn-sm" onClick={logout}>{t('nav.logout')}</button>
            </>
          )}
          {user?.role === 'admin' && (
            <>
              <Link to="/admin" className="btn btn-ghost btn-sm">{t('nav.admin')}</Link>
              <button className="btn btn-sm" onClick={logout}>{t('nav.logout')}</button>
            </>
          )}
        </div>
      </div>
    </header>
  )
}
