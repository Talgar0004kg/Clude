// База данных SQLite. Файл создаётся автоматически в data/app.db.
// При первом запуске создаются таблицы и добавляются демо-данные.

import Database from 'better-sqlite3'
import bcrypt from 'bcryptjs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { mkdirSync } from 'fs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const dataDir = join(__dirname, 'data')
mkdirSync(dataDir, { recursive: true })

export const db = new Database(join(dataDir, 'app.db'))
db.pragma('journal_mode = WAL')

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'business',
    business_id INTEGER,
    name TEXT
  );

  CREATE TABLE IF NOT EXISTS businesses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    type TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    brand_color TEXT DEFAULT '#2563eb',
    brand_emoji TEXT DEFAULT '💬',
    whatsapp_number TEXT,
    bot_greeting TEXT,
    bot_services TEXT,
    bot_schedule TEXT,
    bot_rules TEXT,
    bot_tone TEXT DEFAULT 'friendly'
  );

  CREATE TABLE IF NOT EXISTS leads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    business_id INTEGER NOT NULL,
    name TEXT,
    phone TEXT,
    context TEXT,
    status TEXT NOT NULL DEFAULT 'new',
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS chats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    business_id INTEGER NOT NULL,
    customer TEXT,
    messages TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    business_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  );
`)

// ---------- Демо-данные при первом запуске ----------
const count = db.prepare('SELECT COUNT(*) AS n FROM businesses').get().n
if (count === 0) {
  const insertBiz = db.prepare(`
    INSERT INTO businesses (slug, name, type, status, brand_color, brand_emoji, whatsapp_number,
      bot_greeting, bot_services, bot_schedule, bot_rules, bot_tone)
    VALUES (@slug, @name, @type, @status, @brand_color, @brand_emoji, @whatsapp_number,
      @bot_greeting, @bot_services, @bot_schedule, @bot_rules, @bot_tone)
  `)

  const barber = insertBiz.run({
    slug: 'barber-almaz', name: 'Барбершоп «Алмаз»', type: 'Барбершоп', status: 'active',
    brand_color: '#1f6feb', brand_emoji: '💈', whatsapp_number: '',
    bot_greeting: 'Салам! 👋 Это барбершоп «Алмаз». Чем могу помочь — стрижка, борода, запись?',
    bot_services: 'Мужская стрижка — 500 сом\nСтрижка + борода — 800 сом\nДетская стрижка — 350 сом',
    bot_schedule: 'Пн–Сб: 10:00–20:00, Вс выходной. Свободно сегодня: 15:00, 16:30, 18:00.',
    bot_rules: 'Адрес: ул. Чуй 120. Оплата наличными и картой.',
    bot_tone: 'friendly',
  })

  insertBiz.run({
    slug: 'beauty-aiana', name: 'Салон красоты «Айана»', type: 'Салон красоты', status: 'active',
    brand_color: '#db2777', brand_emoji: '💅', whatsapp_number: '',
    bot_greeting: 'Здравствуйте! 🌸 Салон «Айана». Подскажу по услугам и помогу записаться.',
    bot_services: 'Маникюр — 700 сом\nПедикюр — 900 сом\nОкрашивание — от 2500 сом',
    bot_schedule: 'Ежедневно 09:00–21:00. Свободно сегодня: 12:00, 14:00, 17:30.',
    bot_rules: 'Адрес: пр. Манаса 45. Предоплата 20%.',
    bot_tone: 'formal',
  })

  const hash = bcrypt.hashSync('demo', 10)
  const insertUser = db.prepare('INSERT INTO users (email, password_hash, role, business_id, name) VALUES (?, ?, ?, ?, ?)')
  insertUser.run('business@demo.kg', hash, 'business', barber.lastInsertRowid, 'Барбершоп «Алмаз»')
  insertUser.run('admin@demo.kg', hash, 'admin', null, 'Администратор')

  // немного событий и заявок для статистики
  const insertLead = db.prepare('INSERT INTO leads (business_id, name, phone, context, status) VALUES (?, ?, ?, ?, ?)')
  insertLead.run(barber.lastInsertRowid, 'Бакыт', '+996 555 12 34 56', 'Стрижка + борода на 18:00', 'new')
  insertLead.run(barber.lastInsertRowid, 'Эрлан', '+996 700 98 76 54', 'Детская стрижка завтра', 'contacted')

  console.log('✅ База инициализирована демо-данными.')
}
