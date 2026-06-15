import { Router } from 'express'
import { db } from '../db.js'
import { auth } from '../services/authMiddleware.js'
import { serializeBusiness } from '../services/serialize.js'

const router = Router()
router.use(auth('admin'))

router.get('/businesses', (req, res) => {
  const rows = db.prepare('SELECT * FROM businesses ORDER BY id DESC').all()
  res.json(rows.map(serializeBusiness))
})

router.patch('/businesses/:id/status', (req, res) => {
  const { status } = req.body || {}
  if (!['active', 'pending', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'bad_status' })
  }
  db.prepare('UPDATE businesses SET status = ? WHERE id = ?').run(status, req.params.id)
  res.json({ ok: true })
})

export default router
