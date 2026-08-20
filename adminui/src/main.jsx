import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import { initPwa } from './pwa/registerSW.js'

// Registered outside React so it runs once per page load, not per mount.
initPwa()

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
