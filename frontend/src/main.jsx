import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'

// Production-only DevTools & source inspection deterrent (keeps localhost dev unrestricted)
const isLocalHost = ['localhost', '127.0.0.1'].includes(window.location.hostname)
if (import.meta.env.PROD && !isLocalHost) {
  document.addEventListener('contextmenu', (e) => e.preventDefault())

  document.addEventListener('keydown', (e) => {
    const key = e.key?.toUpperCase()
    const isF12 = e.key === 'F12' || e.keyCode === 123
    const isDevShortcut =
      (e.ctrlKey || e.metaKey) &&
      e.shiftKey &&
      (key === 'I' || key === 'J' || key === 'C')
    const isMacOptDev =
      e.metaKey && e.altKey && (key === 'I' || key === 'J' || key === 'C' || key === 'U')
    const isViewSource = (e.ctrlKey || e.metaKey) && key === 'U'

    if (isF12 || isDevShortcut || isMacOptDev || isViewSource) {
      e.preventDefault()
      e.stopPropagation()
    }
  })
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
