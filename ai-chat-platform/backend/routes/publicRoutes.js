import { Router } from 'express'
import { db } from '../db.js'
import { askBot } from '../services/deepseek.js'
import { notifyLead } from '../services/whatsapp.js'
import { serializeBusiness } from '../services/serialize.js'

const router = Router()

// простая защита от спама: счётчик по IP
const hits = new Map()
const LIMIT = parseInt(process.env.RATE_LIMIT_PER_MIN || '20', 10)
function rateLimit(req, res, next) {
  const ip = req.ip
  const now = Date.now()
  const rec = hits.get(ip) || { count: 0, reset: now + 60000 }
  if (now > rec.reset) { rec.count = 0; rec.reset = now + 60000 }
  rec.count++
  hits.set(ip, rec)
  if (rec.count > LIMIT) return res.status(429).json({ error: 'too_many_requests' })
  next()
}

// Публичные данные бизнеса для чата
router.get('/business/:slug', (req, res) => {
  const b = db.prepare('SELECT * FROM businesses WHERE slug = ?').get(req.params.slug)
  if (!b || b.status !== 'active') return res.status(404).json({ error: 'not_found' })
  db.prepare(`INSERT INTO events (business_id, type) VALUES (?, 'visit')`).run(b.id)
  res.json(serializeBusiness(b))
})

// Сообщение боту
router.post('/chat/:slug', rateLimit, async (req, res) => {
  const b = db.prepare('SELECT * FROM businesses WHERE slug = ?').get(req.params.slug)
  if (!b || b.status !== 'active') return res.status(404).json({ error: 'not_found' })
  const history = req.body?.history || []
  // первое сообщение пользователя = начало переписки
  if (history.filter((m) => m.role === 'user').length === 1) {
    db.prepare(`INSERT INTO events (business_id, type) VALUES (?, 'chat')`).run(b.id)
  }
  try {
    const result = await askBot(b, history)
    res.json(result)
  } catch (e) {
    console.error(e)
    res.status(500).json({ error: 'bot_error', message: e.message })
  }
})

// Заявка от клиента
router.post('/lead/:slug', async (req, res) => {
  const b = db.prepare('SELECT * FROM businesses WHERE slug = ?').get(req.params.slug)
  if (!b) return res.status(404).json({ error: 'not_found' })
  const { name, phone, context } = req.body || {}
  db.prepare(
    'INSERT INTO leads (business_id, name, phone, context, status) VALUES (?, ?, ?, ?, ?)'
  ).run(b.id, name, phone, context || '', 'new')
  db.prepare(`INSERT INTO events (business_id, type) VALUES (?, 'lead')`).run(b.id)

  // уведомление в WhatsApp (если включено и номер задан)
  notifyLead(b, { name, phone, context }).catch(() => {})

  res.json({ ok: true })
})

export default router
