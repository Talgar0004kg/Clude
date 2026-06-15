import { useEffect, useState } from 'react'
import { Routes, Route, NavLink, Navigate } from 'react-router-dom'
import { useT } from '../../i18n'
import { dashboard, IS_DEMO } from '../../api/client'
import BotSettings from './BotSettings'
import Leads from './Leads'
import ChatHistory from './ChatHistory'
import Stats from './Stats'

const statusBadge = {
  active: 'badge-green',
  pending: 'badge-amber',
  rejected: 'badge-red',
}

export default function Dashboard() {
  const { t } = useT()
  const [business, setBusiness] = useState(null)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    dashboard.getMyBusiness().then(setBusiness)
  }, [])

  const link = business ? `${window.location.origin}${window.location.pathname}#/c/${business.slug}` : ''

  const copy = () => {
    navigator.clipboard.writeText(link)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  const statusKey = business ? `dash.status.${business.status === 'active' ? 'active' : business.status === 'pending' ? 'pending' : 'rejected'}` : ''

  return (
    <main className="container section dash">
      <div className="between dash-head">
        <div>
          <h1 className="section-title" style={{ marginBottom: 4 }}>{t('dash.title')}</h1>
          {business && (
            <span className={`badge ${statusBadge[business.status] || 'badge-gray'}`}>
              {t(statusKey)}
            </span>
          )}
        </div>
      </div>

      {business && business.status === 'active' && (
        <div className="card link-card">
          <div>
            <div className="label" style={{ marginBottom: 2 }}>{t('dash.link.title')}</div>
            <code className="link-code">{link}</code>
          </div>
          <button className="btn btn-primary btn-sm" onClick={copy}>
            {copied ? t('dash.link.copied') : t('dash.link.copy')}
          </button>
        </div>
      )}

      <div className="dash-layout">
        <aside className="dash-nav">
          <NavLink to="/dashboard/bot" className="dash-link">🤖 {t('dash.menu.bot')}</NavLink>
          <NavLink to="/dashboard/leads" className="dash-link">📥 {t('dash.menu.leads')}</NavLink>
          <NavLink to="/dashboard/chats" className="dash-link">💬 {t('dash.menu.chats')}</NavLink>
          <NavLink to="/dashboard/stats" className="dash-link">📊 {t('dash.menu.stats')}</NavLink>
        </aside>

        <section className="dash-content">
          <Routes>
            <Route index element={<Navigate to="bot" replace />} />
            <Route path="bot" element={<BotSettings onChange={setBusiness} />} />
            <Route path="leads" element={<Leads />} />
            <Route path="chats" element={<ChatHistory />} />
            <Route path="stats" element={<Stats />} />
          </Routes>
        </section>
      </div>

      {IS_DEMO && (
        <p className="hint demo-note">⚙️ {t('common.demo')}: данные сохраняются локально в браузере. Реальный бэкенд подключается через VITE_API_URL.</p>
      )}
    </main>
  )
}
