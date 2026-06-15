// Вызов DeepSeek API. Ключ берётся из переменных окружения и НИКОГДА
// не передаётся на фронтенд.

import { buildBrain, detectOrderIntent } from './brain.js'

const API_KEY = process.env.DEEPSEEK_API_KEY
const MODEL = process.env.DEEPSEEK_MODEL || 'deepseek-chat'
const BASE_URL = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com'

// history: [{ role: 'user'|'assistant', text }]
export async function askBot(business, history) {
  const systemPrompt = buildBrain(business)
  const lastUser = [...history].reverse().find((m) => m.role === 'user')?.text || ''

  // Если ключа нет — отвечаем заглушкой (чтобы сервер работал без DeepSeek)
  if (!API_KEY) {
    return {
      reply: 'Бот работает в тестовом режиме (DeepSeek-ключ не задан). Укажите DEEPSEEK_API_KEY в .env.',
      intent: detectOrderIntent(lastUser) ? 'order' : null,
    }
  }

  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.map((m) => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text })),
  ]

  const res = await fetch(`${BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${API_KEY}`,
    },
    body: JSON.stringify({ model: MODEL, messages, temperature: 0.6, max_tokens: 500 }),
  })

  if (!res.ok) {
    const err = await res.text().catch(() => '')
    throw new Error(`DeepSeek error ${res.status}: ${err}`)
  }

  const data = await res.json()
  const reply = data.choices?.[0]?.message?.content?.trim() || '…'

  // Намерение заказа: по тексту пользователя ИЛИ если бот просит контакты
  const intent =
    detectOrderIntent(lastUser) ||
    /телефон|номер|как.*обращат|имя/i.test(reply)
      ? 'order'
      : null

  return { reply, intent }
}
