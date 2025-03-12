import React from 'react';
import ReactDOM from 'react-dom/client';
import './i18n'; // Імпортуємо i18n перед App
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

reportWebVitals();

