// Преобразует строку таблицы businesses в формат, понятный фронтенду.

export function serializeBusiness(b) {
  return {
    id: String(b.id),
    slug: b.slug,
    name: b.name,
    type: b.type,
    status: b.status,
    whatsappNumber: b.whatsapp_number,
    brand: { color: b.brand_color, emoji: b.brand_emoji },
    bot: {
      greeting: b.bot_greeting,
      services: b.bot_services,
      schedule: b.bot_schedule,
      rules: b.bot_rules,
      tone: b.bot_tone,
    },
  }
}
