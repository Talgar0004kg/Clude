import { useEffect, useState } from 'react'
import { useT } from '../../i18n'
import { dashboard } from '../../api/client'
import { buildBrain } from '../../utils/buildBrain'

const empty = { greeting: '', services: '', schedule: '', rules: '', tone: 'friendly' }

export default function BotSettings({ onChange }) {
  const { t } = useT()
  const [business, setBusiness] = useState(null)
  const [bot, setBot] = useState(empty)
  const [saved, setSaved] = useState(false)
  const [reviewed, setReviewed] = useState(false)

  useEffect(() => {
    dashboard.getMyBusiness().then((b) => {
      setBusiness(b)
      setBot({ ...empty, ...b.bot })
    })
  }, [])

  const update = (key, value) => {
    setBot((prev) => ({ ...prev, [key]: value }))
    setSaved(false)
  }

  const save = async () => {
    await dashboard.saveBot(bot)
    setSaved(true)
    setTimeout(() => setSaved(false), 1500)
  }

  const submitReview = async () => {
    await dashboard.saveBot(bot)
    await dashboard.submitForReview()
    setReviewed(true)
    const updated = await dashboard.getMyBusiness()
    onChange?.(updated)
    setTimeout(() => setReviewed(false), 2500)
  }

  if (!business) return <p className="muted">{t('common.loading')}</p>

  const brain = buildBrain(business.name, business.type, bot)

  return (
    <div>
      <h2 style={{ marginTop: 0 }}>{t('bot.title')}</h2>
      <p className="section-sub">{t('bot.subtitle')}</p>

      <div className="bot-grid">
        <div className="card">
          <div className="field">
            <label className="label">{t('bot.greeting')}</label>
            <textarea className="textarea" value={bot.greeting} onChange={(e) => update('greeting', e.target.value)} />
          </div>
          <div className="field">
            <label className="label">{t('bot.services')}</label>
            <textarea className="textarea" value={bot.services} onChange={(e) => update('services', e.target.value)} />
          </div>
          <div className="field">
            <label className="label">{t('bot.schedule')}</label>
            <textarea className="textarea" value={bot.schedule} onChange={(e) => update('schedule', e.target.value)} />
          </div>
          <div className="field">
            <label className="label">{t('bot.rules')}</label>
            <textarea className="textarea" value={bot.rules} onChange={(e) => update('rules', e.target.value)} />
          </div>
          <div className="field">
            <label className="label">{t('bot.tone')}</label>
            <select className="select" value={bot.tone} onChange={(e) => update('tone', e.target.value)}>
              <option value="friendly">{t('bot.tone.friendly')}</option>
              <option value="formal">{t('bot.tone.formal')}</option>
              <option value="short">{t('bot.tone.short')}</option>
            </select>
          </div>

          <div className="row">
            <button className="btn btn-primary" onClick={save}>
              {saved ? t('common.saved') : t('common.save')}
            </button>
            <button className="btn btn-ghost" onClick={submitReview}>
              {reviewed ? t('bot.savedForReview') : t('bot.submitForReview')}
            </button>
          </div>
        </div>

        <div className="card brain-card">
          <div className="label">{t('bot.preview')}</div>
          <pre className="brain">{brain}</pre>
        </div>
      </div>
    </div>
  )
}
