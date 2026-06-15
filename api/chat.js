// Vercel-серверная функция: проксирует запрос к DeepSeek.
// Ключ DEEPSEEK_API_KEY хранится в переменных окружения Vercel (не в коде!),
// поэтому он не виден в браузере, а запрос идёт с того же домена — CORS не мешает.
//
// Фронтенд присылает { system, history }, где system — MD-«мозг» бизнеса,
// history — массив сообщений [{ role: 'user'|'assistant', text }].

const ORDER_INTENT = [
  'хочу', 'запиш', 'записать', 'заброниров', 'бронь', 'заказать', 'заказ',
  'купить', 'оформ', 'давайте', 'согласен', 'беру', 'буюрт', 'жазыл',
]
function detectOrderIntent(text = '') {
  const low = text.toLowerCase()
  return ORDER_INTENT.some((w) => low.includes(w))
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  const key = process.env.DEEPSEEK_API_KEY
  const model = process.env.DEEPSEEK_MODEL || 'deepseek-chat'
  const baseUrl = process.env.DEEPSEEK_BASE_URL || 'https://api.deepseek.com'

  // Тело запроса может прийти строкой — подстрахуемся
  let body = req.body
  if (typeof body === 'string') {
    try { body = JSON.parse(body) } catch { body = {} }
  }
  const system = body?.system || 'Ты — вежливый онлайн-консультант бизнеса.'
  const history = Array.isArray(body?.history) ? body.history : []
  const lastUser = [...history].reverse().find((m) => m.role === 'user')?.text || ''

  if (!key) {
    res.status(500).json({ error: 'no_key', reply: 'Ключ DeepSeek не задан в настройках Vercel (DEEPSEEK_API_KEY).', intent: null })
    return
  }

  const messages = [
    { role: 'system', content: system },
    ...history.map((m) => ({ role: m.role === 'user' ? 'user' : 'assistant', content: m.text })),
  ]

  try {
    const r = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify({ model, messages, temperature: 0.6, max_tokens: 600 }),
    })
    if (!r.ok) {
      const errText = await r.text().catch(() => '')
      res.status(502).json({ error: 'deepseek_error', reply: `Ошибка DeepSeek (${r.status}).`, detail: errText, intent: null })
      return
    }
    const data = await r.json()
    const reply = data.choices?.[0]?.message?.content?.trim() || '…'
    const intent =
      detectOrderIntent(lastUser) || /телефон|номер|как.*обращат|ваше имя/i.test(reply)
        ? 'order'
        : null
    res.status(200).json({ reply, intent })
  } catch (e) {
    res.status(500).json({ error: 'server_error', reply: 'Не удалось связаться с AI. Попробуйте ещё раз.', detail: String(e), intent: null })
  }
}
