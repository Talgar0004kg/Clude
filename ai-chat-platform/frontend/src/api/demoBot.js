// Простой симулятор бота для ДЕМО-режима (без реального DeepSeek).
// На бэкенде это заменяется вызовом DeepSeek с MD-«мозгом» бизнеса.

const ORDER_INTENT = [
  'хочу', 'запиш', 'записать', 'заброниров', 'бронь', 'заказать', 'заказ',
  'купить', 'оформ', 'давайте', 'согласен', 'беру', 'буюрт', 'жазыл',
]

const PRICE_WORDS = ['цена', 'цены', 'сколько', 'стоит', 'прайс', 'баа', 'канча']
const TIME_WORDS = ['время', 'график', 'когда', 'часы', 'свобод', 'окошк', 'убакыт', 'график']
const ADDR_WORDS = ['адрес', 'где', 'находит', 'дарек', 'кайда']

function pick(text, words) {
  const low = text.toLowerCase()
  return words.some((w) => low.includes(w))
}

// Возвращает { reply, intent } где intent === 'order' означает «пора брать анкету»
export function demoBotReply(business, history) {
  const last = history[history.length - 1]?.text || ''

  if (pick(last, ORDER_INTENT)) {
    return {
      reply: 'Отлично! Чтобы оформить, подскажите, пожалуйста, как к вам обращаться и ваш номер телефона. 📝',
      intent: 'order',
    }
  }
  if (pick(last, PRICE_WORDS)) {
    return { reply: `Вот наши услуги и цены:\n\n${business.bot.services}\n\nЧто вас интересует?`, intent: null }
  }
  if (pick(last, TIME_WORDS)) {
    return { reply: `${business.bot.schedule}\n\nХотите записаться?`, intent: null }
  }
  if (pick(last, ADDR_WORDS)) {
    return { reply: business.bot.rules, intent: null }
  }
  if (history.length <= 1) {
    return { reply: 'Расскажите, что вас интересует — цены, свободное время или запись?', intent: null }
  }
  return {
    reply: 'Подскажу по услугам, ценам и записи. Что именно вас интересует? Если готовы записаться — просто напишите «хочу записаться».',
    intent: null,
  }
}
