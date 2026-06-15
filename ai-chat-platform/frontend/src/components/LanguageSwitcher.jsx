import { useT } from '../i18n'

export default function LanguageSwitcher({ light }) {
  const { lang, setLang } = useT()
  return (
    <div className={`lang-switch ${light ? 'lang-switch-light' : ''}`}>
      <button
        className={lang === 'ru' ? 'active' : ''}
        onClick={() => setLang('ru')}
      >
        RU
      </button>
      <button
        className={lang === 'ky' ? 'active' : ''}
        onClick={() => setLang('ky')}
      >
        KY
      </button>
    </div>
  )
}
