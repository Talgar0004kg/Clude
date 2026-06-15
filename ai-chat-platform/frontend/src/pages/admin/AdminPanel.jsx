import { useEffect, useState } from 'react'
import { useT } from '../../i18n'
import { admin } from '../../api/client'

const statusBadge = { active: 'badge-green', pending: 'badge-amber', rejected: 'badge-red' }

export default function AdminPanel() {
  const { t } = useT()
  const [list, setList] = useState(null)

  const load = () => admin.getBusinesses().then(setList)
  useEffect(() => { load() }, [])

  const setStatus = async (id, status) => {
    await admin.setStatus(id, status)
    setList((l) => l.map((b) => (b.id === id ? { ...b, status } : b)))
  }

  if (!list) return <main className="container section"><p className="muted">{t('common.loading')}</p></main>

  const stats = {
    total: list.length,
    active: list.filter((b) => b.status === 'active').length,
    pending: list.filter((b) => b.status === 'pending').length,
  }

  return (
    <main className="container section">
      <h1 className="section-title">{t('admin.title')}</h1>

      <div className="stat-cards" style={{ marginBottom: 22 }}>
        <div className="card stat-card"><div className="stat-icon" style={{ background: '#2563eb' }}>🏢</div><div><div className="stat-value">{stats.total}</div><div className="muted">{t('admin.totalBusinesses')}</div></div></div>
        <div className="card stat-card"><div className="stat-icon" style={{ background: '#16a34a' }}>🤖</div><div><div className="stat-value">{stats.active}</div><div className="muted">{t('admin.activeBots')}</div></div></div>
        <div className="card stat-card"><div className="stat-icon" style={{ background: '#d97706' }}>⏳</div><div><div className="stat-value">{stats.pending}</div><div className="muted">{t('admin.pendingReview')}</div></div></div>
      </div>

      <div className="card table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>{t('admin.businesses')}</th>
              <th>{t('bot.businessType')}</th>
              <th>{t('leads.status')}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {list.map((b) => (
              <tr key={b.id}>
                <td>
                  <div className="row" style={{ alignItems: 'center', gap: 10 }}>
                    <span className="admin-emoji" style={{ background: b.brand.color }}>{b.brand.emoji}</span>
                    <strong>{b.name}</strong>
                  </div>
                </td>
                <td className="muted">{b.type}</td>
                <td><span className={`badge ${statusBadge[b.status] || 'badge-gray'}`}>{t(`dash.status.${b.status === 'active' ? 'active' : b.status === 'pending' ? 'pending' : 'rejected'}`)}</span></td>
                <td>
                  <div className="row">
                    {b.status !== 'active' && (
                      <button className="btn btn-success btn-sm" onClick={() => setStatus(b.id, 'active')}>{t('admin.approve')}</button>
                    )}
                    {b.status !== 'rejected' && (
                      <button className="btn btn-danger btn-sm" onClick={() => setStatus(b.id, 'rejected')}>{t('admin.reject')}</button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </main>
  )
}
