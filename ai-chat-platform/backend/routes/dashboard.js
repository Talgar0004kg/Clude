import { Router } from 'express'
import { db } from '../db.js'
import { auth } from '../services/authMiddleware.js'
import { serializeBusiness } from '../services/serialize.js'

const router = Router()
router.use(auth('business'))

function myBusiness(req) {
  return db.prepare('SELECT * FROM businesses WHERE id = ?').get(req.user.business_id)
}

router.get('/business', (req, res) => {
  const b = myBusiness(req)
  if (!b) return res.status(404).json({ error: 'not_found' })
  res.json(serializeBusiness(b))
})

router.put('/bot', (req, res) => {
  const { greeting, services, schedule, rules, tone } = req.body || {}
  db.prepare(`
    UPDATE businesses
    SET bot_greeting = ?, bot_services = ?, bot_schedule = ?, bot_rules = ?, bot_tone = ?
    WHERE id = ?
  `).run(greeting, services, schedule, rules, tone, req.user.business_id)
  res.json({ ok: true })
})

router.post('/submit-review', (req, res) => {
  db.prepare(`UPDATE businesses SET status = 'pending' WHERE id = ?`).run(req.user.business_id)
  res.json({ ok: true })
})

router.get('/leads', (req, res) => {
  const rows = db.prepare('SELECT * FROM leads WHERE business_id = ? ORDER BY created_at DESC').all(req.user.business_id)
  res.json(rows.map((l) => ({
    id: String(l.id), businessId: String(l.business_id), name: l.name, phone: l.phone,
    context: l.context, status: l.status, date: l.created_at,
  })))
})

router.patch('/leads/:id', (req, res) => {
  db.prepare('UPDATE leads SET status = ? WHERE id = ? AND business_id = ?')
    .run(req.body.status, req.params.id, req.user.business_id)
  res.json({ ok: true })
})

router.get('/chats', (req, res) => {
  const rows = db.prepare('SELECT * FROM chats WHERE business_id = ? ORDER BY created_at DESC').all(req.user.business_id)
  res.json(rows.map((c) => ({
    id: String(c.id), businessId: String(c.business_id), customer: c.customer,
    date: c.created_at, messages: JSON.parse(c.messages || '[]'),
  })))
})

router.get('/stats', (req, res) => {
  const bid = req.user.business_id
  const countByType = (type) =>
    db.prepare('SELECT COUNT(*) AS n FROM events WHERE business_id = ? AND type = ?').get(bid, type).n

  // события по дням за последние 7 дней
  const byDay = []
  for (let i = 6; i >= 0; i--) {
    const n = db.prepare(`
      SELECT COUNT(*) AS n FROM events
      WHERE business_id = ? AND type = 'chat'
      AND date(created_at) = date('now', ?)
    `).get(bid, `-${i} days`).n
    byDay.push(n)
  }

  res.json({
    visits: countByType('visit'),
    chats: countByType('chat'),
    leads: countByType('lead'),
    byDay,
  })
})

export default router
