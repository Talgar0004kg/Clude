import { Router } from 'express'
import bcrypt from 'bcryptjs'
import { db } from '../db.js'
import { signToken } from '../services/authMiddleware.js'

const router = Router()

function publicUser(u) {
  return { id: u.id, email: u.email, role: u.role, businessId: u.business_id, name: u.name }
}

router.post('/login', (req, res) => {
  const { email, password } = req.body || {}
  const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email)
  if (!user || !bcrypt.compareSync(password || '', user.password_hash)) {
    return res.status(401).json({ error: 'Неверный email или пароль' })
  }
  res.json({ token: signToken(user), user: publicUser(user) })
})

router.post('/register', (req, res) => {
  const { email, password, businessName } = req.body || {}
  if (!email || !password || !businessName) {
    return res.status(400).json({ error: 'Заполните все поля' })
  }
  const exists = db.prepare('SELECT id FROM users WHERE email = ?').get(email)
  if (exists) return res.status(409).json({ error: 'Email уже зарегистрирован' })

  const slug = businessName.toLowerCase().replace(/[^a-z0-9а-я]+/gi, '-').replace(/(^-|-$)/g, '') + '-' + Date.now().toString(36)
  const biz = db.prepare(
    `INSERT INTO businesses (slug, name, status) VALUES (?, ?, 'pending')`
  ).run(slug, businessName)

  const hash = bcrypt.hashSync(password, 10)
  const user = db.prepare(
    'INSERT INTO users (email, password_hash, role, business_id, name) VALUES (?, ?, ?, ?, ?)'
  ).run(email, hash, 'business', biz.lastInsertRowid, businessName)

  const full = db.prepare('SELECT * FROM users WHERE id = ?').get(user.lastInsertRowid)
  res.json({ token: signToken(full), user: publicUser(full) })
})

export default router
