// API-клиент. Работает в двух режимах:
//  1) ДЕМО (по умолчанию на GitHub Pages) — данные из mockData + localStorage.
//  2) БЭКЕНД — если задан VITE_API_URL, ходит на реальный сервер по REST.
//
// Так фронтенд можно выложить на GitHub Pages автономно, а позже подключить
// бэкенд из ZIP, выставив переменную окружения VITE_API_URL.

import { demoBusinesses, demoLeads, demoChats, demoStats, demoUsers } from './mockData'
import { demoBotReply } from './demoBot'

const API_URL = import.meta.env.VITE_API_URL || ''
export const IS_DEMO = !API_URL

// ---------- localStorage-хранилище для ДЕМО ----------
const LS = {
  get(key, fallback) {
    try {
      const raw = localStorage.getItem(key)
      return raw ? JSON.parse(raw) : fallback
    } catch {
      return fallback
    }
  },
  set(key, value) {
    localStorage.setItem(key, JSON.stringify(value))
  },
}

function seed() {
  if (!LS.get('chatbiz.seeded')) {
    LS.set('chatbiz.businesses', demoBusinesses)
    LS.set('chatbiz.leads', demoLeads)
    LS.set('chatbiz.chats', demoChats)
    LS.set('chatbiz.seeded', true)
  }
}
seed()

const delay = (ms = 350) => new Promise((r) => setTimeout(r, ms))

async function http(path, options = {}) {
  const token = localStorage.getItem('chatbiz.token')
  const res = await fetch(`${API_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
    ...options,
  })
  if (!res.ok) {
    const msg = await res.text().catch(() => res.statusText)
    throw new Error(msg || `HTTP ${res.status}`)
  }
  return res.status === 204 ? null : res.json()
}

// ================= AUTH =================
export const auth = {
  async login(email, password) {
    if (IS_DEMO) {
      await delay()
      const user = demoUsers.find((u) => u.email === email && u.password === password)
      if (!user) throw new Error('Неверный email или пароль')
      const session = { token: 'demo-' + user.role, user }
      localStorage.setItem('chatbiz.token', session.token)
      localStorage.setItem('chatbiz.user', JSON.stringify(user))
      return session
    }
    const session = await http('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    })
    localStorage.setItem('chatbiz.token', session.token)
    localStorage.setItem('chatbiz.user', JSON.stringify(session.user))
    return session
  },

  async register(payload) {
    if (IS_DEMO) {
      await delay()
      const user = { email: payload.email, role: 'business', businessId: 'b-new', name: payload.businessName }
      localStorage.setItem('chatbiz.token', 'demo-business')
      localStorage.setItem('chatbiz.user', JSON.stringify(user))
      return { token: 'demo-business', user }
    }
    const session = await http('/api/auth/register', {
      method: 'POST',
      body: JSON.stringify(payload),
    })
    localStorage.setItem('chatbiz.token', session.token)
    localStorage.setItem('chatbiz.user', JSON.stringify(session.user))
    return session
  },

  logout() {
    localStorage.removeItem('chatbiz.token')
    localStorage.removeItem('chatbiz.user')
  },

  current() {
    try {
      return JSON.parse(localStorage.getItem('chatbiz.user'))
    } catch {
      return null
    }
  },
}

// ================= PUBLIC (чат) =================
export const publicApi = {
  async getBusiness(slug) {
    if (IS_DEMO) {
      await delay(200)
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      const b = list.find((x) => x.slug === slug)
      if (!b || b.status !== 'active') throw new Error('not_found')
      return b
    }
    return http(`/api/public/business/${slug}`)
  },

  async sendMessage(slug, history) {
    if (IS_DEMO) {
      await delay(600)
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      const b = list.find((x) => x.slug === slug)
      return demoBotReply(b, history)
    }
    return http(`/api/public/chat/${slug}`, {
      method: 'POST',
      body: JSON.stringify({ history }),
    })
  },

  async submitLead(slug, lead) {
    if (IS_DEMO) {
      await delay()
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      const b = list.find((x) => x.slug === slug)
      const leads = LS.get('chatbiz.leads', demoLeads)
      leads.unshift({
        id: 'l' + Date.now(),
        businessId: b?.id,
        ...lead,
        status: 'new',
        date: new Date().toISOString(),
      })
      LS.set('chatbiz.leads', leads)
      return { ok: true }
    }
    return http(`/api/public/lead/${slug}`, {
      method: 'POST',
      body: JSON.stringify(lead),
    })
  },
}

// ================= DASHBOARD (бизнес) =================
export const dashboard = {
  async getMyBusiness() {
    if (IS_DEMO) {
      await delay(200)
      const user = auth.current()
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      return list.find((x) => x.id === user?.businessId) || list[0]
    }
    return http('/api/dashboard/business')
  },

  async saveBot(botConfig) {
    if (IS_DEMO) {
      await delay()
      const user = auth.current()
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      const idx = list.findIndex((x) => x.id === user?.businessId)
      if (idx >= 0) {
        list[idx].bot = botConfig
        LS.set('chatbiz.businesses', list)
      }
      return { ok: true }
    }
    return http('/api/dashboard/bot', {
      method: 'PUT',
      body: JSON.stringify(botConfig),
    })
  },

  async submitForReview() {
    if (IS_DEMO) {
      await delay()
      const user = auth.current()
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      const idx = list.findIndex((x) => x.id === user?.businessId)
      if (idx >= 0) {
        list[idx].status = 'pending'
        LS.set('chatbiz.businesses', list)
      }
      return { ok: true }
    }
    return http('/api/dashboard/submit-review', { method: 'POST' })
  },

  async getLeads() {
    if (IS_DEMO) {
      await delay(200)
      const user = auth.current()
      const leads = LS.get('chatbiz.leads', demoLeads)
      return leads.filter((l) => l.businessId === user?.businessId)
    }
    return http('/api/dashboard/leads')
  },

  async updateLeadStatus(id, status) {
    if (IS_DEMO) {
      await delay(150)
      const leads = LS.get('chatbiz.leads', demoLeads)
      const idx = leads.findIndex((l) => l.id === id)
      if (idx >= 0) {
        leads[idx].status = status
        LS.set('chatbiz.leads', leads)
      }
      return { ok: true }
    }
    return http(`/api/dashboard/leads/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    })
  },

  async getChats() {
    if (IS_DEMO) {
      await delay(200)
      const user = auth.current()
      return demoChats.filter((c) => c.businessId === user?.businessId)
    }
    return http('/api/dashboard/chats')
  },

  async getStats() {
    if (IS_DEMO) {
      await delay(200)
      const user = auth.current()
      return demoStats[user?.businessId] || { visits: 0, chats: 0, leads: 0, byDay: [0, 0, 0, 0, 0, 0, 0] }
    }
    return http('/api/dashboard/stats')
  },
}

// ================= ADMIN =================
export const admin = {
  async getBusinesses() {
    if (IS_DEMO) {
      await delay(200)
      return LS.get('chatbiz.businesses', demoBusinesses)
    }
    return http('/api/admin/businesses')
  },

  async setStatus(id, status) {
    if (IS_DEMO) {
      await delay(150)
      const list = LS.get('chatbiz.businesses', demoBusinesses)
      const idx = list.findIndex((x) => x.id === id)
      if (idx >= 0) {
        list[idx].status = status
        LS.set('chatbiz.businesses', list)
      }
      return { ok: true }
    }
    return http(`/api/admin/businesses/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    })
  },
}
