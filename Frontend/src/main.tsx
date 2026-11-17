import { createRoot } from 'react-dom/client';
import { setBaseUrl } from '@workspace/api-client-react';

import App from './App';
import { ErrorBoundary } from '@/components/error-boundary';

import './index.css';

// Point the generated API client at the backend. Without this, generated hooks
// send requests to relative `/api/...` paths on the Pages origin, which returns
// index.html instead of JSON and breaks every list view.
const apiUrl = (import.meta as ImportMeta & {
  env: { VITE_API_URL?: string };
}).env.VITE_API_URL;
if (apiUrl) {
  setBaseUrl(apiUrl);
}

createRoot(document.getElementById('root')!).render(
  <ErrorBoundary>
    <App />
  </ErrorBoundary>,
);