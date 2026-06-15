// Отправка уведомлений о заявках в WhatsApp через whatsapp-web.js.
// Включается переменной WHATSAPP_ENABLED=true. При первом запуске нужно
// отсканировать QR-код (появится в консоли) WhatsApp'ом компании.
//
// ⚠️ Это неофициальный способ. Используйте ОТДЕЛЬНЫЙ номер под рассылку.
// При большом объёме WhatsApp может заблокировать номер.

let client = null
let ready = false

export async function initWhatsApp() {
  if (process.env.WHATSAPP_ENABLED !== 'true') {
    console.log('ℹ️  WhatsApp отключён (WHATSAPP_ENABLED!=true). Заявки сохраняются в кабинете.')
    return
  }

  try {
    const { default: pkg } = await import('whatsapp-web.js')
    const { Client, LocalAuth } = pkg
    const qrcode = (await import('qrcode-terminal')).default

    client = new Client({
      authStrategy: new LocalAuth({ dataPath: './data/wwebjs_auth' }),
      puppeteer: { args: ['--no-sandbox', '--disable-setuid-sandbox'] },
    })

    client.on('qr', (qr) => {
      console.log('\n📲 Отсканируйте QR-код в WhatsApp (Настройки → Связанные устройства):\n')
      qrcode.generate(qr, { small: true })
    })
    client.on('ready', () => {
      ready = true
      console.log('✅ WhatsApp подключён и готов отправлять уведомления.')
    })
    client.on('disconnected', () => {
      ready = false
      console.log('⚠️  WhatsApp отключился.')
    })

    await client.initialize()
  } catch (e) {
    console.error('❌ Не удалось запустить WhatsApp:', e.message)
  }
}

// Форматирует номер в JID WhatsApp (только цифры + @c.us)
function toJid(number) {
  const digits = String(number).replace(/\D/g, '')
  return `${digits}@c.us`
}

export async function notifyLead(business, lead) {
  if (!ready || !client) return false
  const target = business.whatsapp_number
  if (!target) return false

  const text =
    `🔔 Новая заявка с сайта!\n\n` +
    `🏢 ${business.name}\n` +
    `👤 Имя: ${lead.name}\n` +
    `📞 Телефон: ${lead.phone}\n` +
    `💬 Контекст: ${lead.context || '—'}`

  try {
    await client.sendMessage(toJid(target), text)
    return true
  } catch (e) {
    console.error('❌ Ошибка отправки WhatsApp:', e.message)
    return false
  }
}
