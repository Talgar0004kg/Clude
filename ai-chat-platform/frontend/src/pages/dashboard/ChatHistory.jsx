import { useEffect, useState } from 'react'
import { useT } from '../../i18n'
import { dashboard } from '../../api/client'

export default function ChatHistory() {
  const { t } = useT()
  const [chats, setChats] = useState(null)
  const [active, setActive] = useState(null)

  useEffect(() => {
    dashboard.getChats().then((c) => {
      setChats(c)
      setActive(c[0] || null)
    })
  }, [])

  if (!chats) return <p className="muted">{t('common.loading')}</p>

  return (
    <div>
      <h2 style={{ marginTop: 0 }}>{t('chats.title')}</h2>
      {chats.length === 0 ? (
        <div className="card empty-state">💬 {t('chats.empty')}</div>
      ) : (
        <div className="chats-layout">
          <div className="chats-list card">
            {chats.map((c) => (
              <button
                key={c.id}
                className={`chat-item ${active?.id === c.id ? 'active' : ''}`}
                onClick={() => setActive(c)}
              >
                <strong>{c.customer}</strong>
                <span className="muted">{c.messages.length} {t('chats.messages')}</span>
                <span className="muted small">{new Date(c.date).toLocaleString()}</span>
              </button>
            ))}
          </div>

          <div className="card chat-transcript">
            {active && active.messages.map((m, i) => (
              <div key={i} className={`bubble ${m.role === 'user' ? 'user' : 'bot'}`}>{m.text}</div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
