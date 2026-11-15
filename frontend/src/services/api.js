const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000/api/v1';

export const getAuthToken = () => localStorage.getItem('recell_token');
export const setAuthToken = (token) => localStorage.setItem('recell_token', token);
export const removeAuthToken = () => localStorage.removeItem('recell_token');

export const getCurrentUser = () => {
  const userStr = localStorage.getItem('recell_user');
  try {
    return userStr ? JSON.parse(userStr) : null;
  } catch (e) {
    return null;
  }
};
export const setCurrentUser = (user) => localStorage.setItem('recell_user', JSON.stringify(user));
export const removeCurrentUser = () => localStorage.removeItem('recell_user');

async function request(endpoint, options = {}) {
  const token = getAuthToken();
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    ...options.headers,
  };

  const response = await fetch(`${API_BASE}${endpoint}`, {
    ...options,
    headers,
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errorMsg = data.detail || data.message || Object.values(data)[0] || 'API Request Failed';
    throw new Error(typeof errorMsg === 'string' ? errorMsg : JSON.stringify(errorMsg));
  }
  return data;
}

export const api = {
  // Auth
  login: (credentials) => request('/auth/login/', { method: 'POST', body: JSON.stringify(credentials) }),
  register: (payload) => request('/auth/register/', { method: 'POST', body: JSON.stringify(payload) }),
  getMe: () => request('/auth/me/'),
  getAgents: () => request('/auth/agents/'),

  // Catalog
  getBrands: (includeModels = false) => request(`/catalog/brands/?include_models=${includeModels}`),
  getModels: (brandId) => request(`/catalog/models/${brandId ? `?brand=${brandId}` : ''}`),
  getModelDetail: (id) => request(`/catalog/models/${id}/`),
  createVariant: (data) => request('/catalog/variants/', { method: 'POST', body: JSON.stringify(data) }),

  // Valuation
  getConditionCategories: () => request('/valuation/conditions/'),
  calculateEstimate: (variantId, selectedCodes) => 
    request('/valuation/estimate/', {
      method: 'POST',
      body: JSON.stringify({ variant_id: variantId, selected_option_codes: selectedCodes })
    }),
  updateConditionOption: (id, data) => 
    request(`/valuation/conditions/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),

  // Sales
  submitSale: (payload) => request('/sales/', { method: 'POST', body: JSON.stringify(payload) }),
  getSales: (params = {}) => {
    const query = new URLSearchParams(params).toString();
    return request(`/sales/${query ? `?${query}` : ''}`);
  },
  getSaleDetail: (idOrCode) => request(`/sales/${idOrCode}/`),
  acceptOffer: (id) => request(`/sales/${id}/accept-offer/`, { method: 'POST' }),
  rejectOffer: (id) => request(`/sales/${id}/reject-offer/`, { method: 'POST' }),
  assignPickup: (id, payload) => request(`/sales/${id}/schedule-pickup/`, { method: 'POST', body: JSON.stringify(payload) }),
  transferOwnership: (id, payload) => request(`/sales/${id}/transfer-ownership/`, { method: 'POST', body: JSON.stringify(payload) }),
  adminApproveFinalOffer: (id, payload) => request(`/sales/${id}/approve-final-offer/`, { method: 'POST', body: JSON.stringify(payload) }),

  // Inspection
  recordInspection: (payload) => request('/inspections/', { method: 'POST', body: JSON.stringify(payload) }),

  // Payments (Manual Payout Proof & UTR)
  getPaymentQR: (saleId) => request(`/payments/qr/${saleId}/`),
  recordPayout: (payload) => request('/payments/record-payout/', { method: 'POST', body: JSON.stringify(payload) }),
  getPaymentsList: () => request('/payments/'),
  getPaymentReceipt: (saleCode) => request(`/payments/receipt/${saleCode}/`),
};
