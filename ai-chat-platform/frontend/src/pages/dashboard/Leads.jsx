import { useEffect, useState } from 'react'
import { useT } from '../../i18n'
import { dashboard } from '../../api/client'

const STATUSES = ['new', 'contacted', 'booked', 'done']
const badgeFor = { new: 'badge-blue', contacted: 'badge-amber', booked: 'badge-green', done: 'badge-gray' }

export default function Leads() {
  const { t } = useT()
  const [leads, setLeads] = useState(null)

  useEffect(() => {
    dashboard.getLeads().then(setLeads)
  }, [])

  const changeStatus = async (id, status) => {
    await dashboard.updateLeadStatus(id, status)
    setLeads((list) => list.map((l) => (l.id === id ? { ...l, status } : l)))
  }

  if (!leads) return <p className="muted">{t('common.loading')}</p>

  return (
    <div>
      <h2 style={{ marginTop: 0 }}>{t('leads.title')}</h2>
      {leads.length === 0 ? (
        <div className="card empty-state">📭 {t('leads.empty')}</div>
      ) : (
        <div className="table-wrap card">
          <table className="table">
            <thead>
              <tr>
                <th>{t('leads.name')}</th>
                <th>{t('leads.phone')}</th>
                <th>{t('leads.context')}</th>
                <th>{t('leads.date')}</th>
                <th>{t('leads.status')}</th>
              </tr>
            </thead>
            <tbody>
              {leads.map((l) => (
                <tr key={l.id}>
                  <td><strong>{l.name}</strong></td>
                  <td><a href={`tel:${l.phone}`}>{l.phone}</a></td>
                  <td className="muted">{l.context}</td>
                  <td className="muted">{new Date(l.date).toLocaleDateString()}</td>
                  <td>
                    <select
                      className={`status-select badge ${badgeFor[l.status]}`}
                      value={l.status}
                      onChange={(e) => changeStatus(l.id, e.target.value)}
                    >
                      {STATUSES.map((s) => (
                        <option key={s} value={s}>{t(`leads.status.${s}`)}</option>
                      ))}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
