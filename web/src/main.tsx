import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import {
  applyAppearancePreference,
  readAppearancePreference,
} from './features/settings/appearance.ts'

applyAppearancePreference(readAppearancePreference())

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
