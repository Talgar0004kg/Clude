import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useT } from '../i18n'
import { admin } from '../api/client'

export default function Demo() {
  const { t } = useT()
  const [list, setList] = useState([])

  useEffect(() => {
    admin.getBusinesses().then((all) => setList(all.filter((b) => b.status === 'active')))
  }, [])

  return (
    <main className="container section">
      <h1 className="section-title">{t('demo.title')}</h1>
      <p className="section-sub">{t('demo.subtitle')}</p>

      <div className="features-grid">
        {list.map((b) => (
          <Link to={`/c/${b.slug}`} className="card demo-card" key={b.id}>
            <div className="demo-emoji" style={{ background: b.brand.color }}>{b.brand.emoji}</div>
            <h3>{b.name}</h3>
            <p className="muted">{b.type}</p>
            <span className="btn btn-primary btn-sm">{t('nav.demo')} →</span>
          </Link>
        ))}
      </div>
    </main>
  )
}
