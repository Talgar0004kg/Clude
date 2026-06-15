import { useEffect, useState } from 'react'
import { useT } from '../../i18n'
import { dashboard } from '../../api/client'

export default function Stats() {
  const { t } = useT()
  const [stats, setStats] = useState(null)

  useEffect(() => {
    dashboard.getStats().then(setStats)
  }, [])

  if (!stats) return <p className="muted">{t('common.loading')}</p>

  const conversion = stats.visits ? ((stats.leads / stats.visits) * 100).toFixed(1) : '0.0'
  const max = Math.max(...stats.byDay, 1)
  const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']

  const cards = [
    { label: t('stats.visits'), value: stats.visits, icon: '👀', color: '#2563eb' },
    { label: t('stats.chats'), value: stats.chats, icon: '💬', color: '#7c3aed' },
    { label: t('stats.leads'), value: stats.leads, icon: '📥', color: '#16a34a' },
    { label: t('stats.conversion'), value: conversion + '%', icon: '📈', color: '#d97706' },
  ]

  return (
    <div>
      <h2 style={{ marginTop: 0 }}>{t('stats.title')}</h2>
      <div className="stat-cards">
        {cards.map((c, i) => (
          <div className="card stat-card" key={i}>
            <div className="stat-icon" style={{ background: c.color }}>{c.icon}</div>
            <div>
              <div className="stat-value">{c.value}</div>
              <div className="muted">{c.label}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="card" style={{ marginTop: 18 }}>
        <div className="label">{t('stats.chats')} ({t('stats.visits')})</div>
        <div className="bar-chart">
          {stats.byDay.map((v, i) => (
            <div className="bar-col" key={i}>
              <div className="bar" style={{ height: `${(v / max) * 100}%` }} title={v}><span>{v}</span></div>
              <div className="bar-label">{days[i]}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
