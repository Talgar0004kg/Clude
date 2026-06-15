import 'dotenv/config'
import express from 'express'
import cors from 'cors'

import './db.js' // инициализация БД
import authRoutes from './routes/auth.js'
import publicRoutes from './routes/publicRoutes.js'
import dashboardRoutes from './routes/dashboard.js'
import adminRoutes from './routes/admin.js'
import { initWhatsApp } from './services/whatsapp.js'

const app = express()
app.set('trust proxy', true)
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }))
app.use(express.json({ limit: '1mb' }))

app.get('/api/health', (req, res) => res.json({ ok: true, ts: Date.now() }))

app.use('/api/auth', authRoutes)
app.use('/api/public', publicRoutes)
app.use('/api/dashboard', dashboardRoutes)
app.use('/api/admin', adminRoutes)

const PORT = process.env.PORT || 4000
app.listen(PORT, () => {
  console.log(`\n🚀 Бэкенд ChatBiz запущен на http://localhost:${PORT}`)
  console.log(`   Демо-вход: business@demo.kg / demo · admin@demo.kg / demo`)
  initWhatsApp()
})
