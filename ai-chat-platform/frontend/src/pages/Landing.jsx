import { Link } from 'react-router-dom'
import { useT } from '../i18n'

export default function Landing() {
  const { t } = useT()

  const features = [
    { icon: '🤖', title: t('landing.f1.title'), text: t('landing.f1.text') },
    { icon: '📲', title: t('landing.f2.title'), text: t('landing.f2.text') },
    { icon: '📊', title: t('landing.f3.title'), text: t('landing.f3.text') },
    { icon: '🔗', title: t('landing.f4.title'), text: t('landing.f4.text') },
  ]

  const steps = [
    t('landing.how.s1'),
    t('landing.how.s2'),
    t('landing.how.s3'),
    t('landing.how.s4'),
  ]

  return (
    <main>
      {/* HERO */}
      <section className="hero">
        <div className="container hero-inner">
          <div className="hero-text">
            <span className="badge badge-blue">✨ {t('app.tagline')}</span>
            <h1>{t('landing.hero.title')}</h1>
            <p className="hero-sub">{t('landing.hero.subtitle')}</p>
            <div className="hero-cta">
              <Link to="/demo" className="btn btn-primary">{t('landing.hero.cta')}</Link>
              <Link to="/register" className="btn btn-light">{t('landing.hero.cta2')}</Link>
            </div>
          </div>
          <div className="hero-visual">
            <ChatPreview />
          </div>
        </div>
      </section>

      {/* PROBLEM */}
      <section className="container section">
        <div className="card problem-card">
          <h2 className="section-title">{t('landing.problem.title')}</h2>
          <p className="muted" style={{ margin: 0, fontSize: 17 }}>{t('landing.problem.text')}</p>
        </div>
      </section>

      {/* FEATURES */}
      <section className="container section" id="features">
        <h2 className="section-title">{t('landing.features.title')}</h2>
        <div className="features-grid">
          {features.map((f, i) => (
            <div className="card feature" key={i}>
              <div className="feature-icon">{f.icon}</div>
              <h3>{f.title}</h3>
              <p className="muted">{f.text}</p>
            </div>
          ))}
        </div>
      </section>

      {/* HOW */}
      <section className="container section" id="how">
        <h2 className="section-title">{t('landing.how.title')}</h2>
        <div className="steps">
          {steps.map((s, i) => (
            <div className="step" key={i}>
              <div className="step-num">{i + 1}</div>
              <p>{s}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="container section">
        <div className="cta-banner">
          <h2>{t('landing.cta.title')}</h2>
          <p>{t('landing.cta.text')}</p>
          <Link to="/demo" className="btn btn-light">{t('landing.hero.cta')}</Link>
        </div>
      </section>

      <footer className="footer">
        <div className="container between">
          <span>💬 {t('app.name')} — {t('app.tagline')}</span>
          <span className="muted">© 2026</span>
        </div>
      </footer>
    </main>
  )
}

function ChatPreview() {
  return (
    <div className="chat-preview">
      <div className="chat-preview-head">💈 Барбершоп «Алмаз» · <span className="online">●</span> на связи</div>
      <div className="chat-preview-body">
        <div className="bubble bot">Салам! 👋 Чем могу помочь?</div>
        <div className="bubble user">Сколько стоит стрижка с бородой?</div>
        <div className="bubble bot">Стрижка + борода — 800 сом. Свободно в 15:00 и 18:00. Записать вас?</div>
        <div className="bubble user">Да, на 18:00</div>
        <div className="bubble bot">Подскажите имя и номер телефона 📝</div>
      </div>
    </div>
  )
}
