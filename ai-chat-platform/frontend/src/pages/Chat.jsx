import { useEffect, useRef, useState } from 'react'
import { useParams } from 'react-router-dom'
import { useT } from '../i18n'
import { publicApi } from '../api/client'

export default function Chat() {
  const { slug } = useParams()
  const { t } = useT()
  const [business, setBusiness] = useState(null)
  const [error, setError] = useState(false)
  const [messages, setMessages] = useState([])
  const [input, setInput] = useState('')
  const [typing, setTyping] = useState(false)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ name: '', phone: '' })
  const [submitted, setSubmitted] = useState(false)
  const bodyRef = useRef(null)

  useEffect(() => {
    publicApi
      .getBusiness(slug)
      .then((b) => {
        setBusiness(b)
        setMessages([{ role: 'assistant', text: b.bot.greeting }])
      })
      .catch(() => setError(true))
  }, [slug])

  useEffect(() => {
    if (bodyRef.current) bodyRef.current.scrollTop = bodyRef.current.scrollHeight
  }, [messages, typing, showForm])

  const send = async () => {
    const text = input.trim()
    if (!text || typing) return
    const next = [...messages, { role: 'user', text }]
    setMessages(next)
    setInput('')
    setTyping(true)
    try {
      const { reply, intent } = await publicApi.sendMessage(slug, next)
      setMessages((m) => [...m, { role: 'assistant', text: reply }])
      if (intent === 'order') setShowForm(true)
    } finally {
      setTyping(false)
    }
  }

  const submitLead = async (e) => {
    e.preventDefault()
    const context = messages
      .filter((m) => m.role === 'user')
      .slice(-3)
      .map((m) => m.text)
      .join(' · ')
    await publicApi.submitLead(slug, { ...form, context })
    setSubmitted(true)
    setShowForm(false)
    setMessages((m) => [...m, { role: 'assistant', text: t('chat.form.success') }])
  }

  if (error) {
    return (
      <div className="chat-page chat-center">
        <div className="card" style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 42 }}>🤖</div>
          <p>{t('chat.notFound')}</p>
        </div>
      </div>
    )
  }

  if (!business) {
    return <div className="chat-page chat-center"><p className="muted">{t('common.loading')}</p></div>
  }

  const color = business.brand.color

  return (
    <div className="chat-page" style={{ '--brand': color }}>
      <div className="chat-box">
        <header className="chat-header" style={{ background: color }}>
          <div className="chat-avatar">{business.brand.emoji}</div>
          <div>
            <div className="chat-title">{business.name}</div>
            <div className="chat-status"><span className="dot" /> {t('chat.online')}</div>
          </div>
        </header>

        <div className="chat-body" ref={bodyRef}>
          {messages.map((m, i) => (
            <div key={i} className={`bubble ${m.role === 'user' ? 'user' : 'bot'}`}>
              {m.text.split('\n').map((line, j) => (
                <div key={j}>{line}</div>
              ))}
            </div>
          ))}
          {typing && (
            <div className="bubble bot typing"><span /><span /><span /></div>
          )}

          {showForm && !submitted && (
            <form className="lead-form" onSubmit={submitLead}>
              <div className="lead-form-title">{t('chat.form.title')}</div>
              <input
                className="input"
                placeholder={t('chat.form.name')}
                value={form.name}
                required
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
              <input
                className="input"
                placeholder={t('chat.form.phone')}
                value={form.phone}
                required
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
              />
              <button className="btn btn-primary btn-block" type="submit" style={{ background: color }}>
                {t('chat.form.submit')}
              </button>
            </form>
          )}
        </div>

        <div className="chat-input">
          <input
            className="input"
            placeholder={t('chat.placeholder')}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && send()}
          />
          <button className="btn btn-primary chat-send" onClick={send} style={{ background: color }} disabled={typing}>
            ➤
          </button>
        </div>
        <div className="chat-foot">{t('chat.poweredBy')}</div>
      </div>
    </div>
  )
}
