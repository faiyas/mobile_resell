// Auto-normalize API URL: Ensure /api/v1 is appended whether the user entered it or not
const getApiBase = () => {
  const defaultProd = 'https://8010-agq5qlr2uletnjyzudtddvxrdq.instabox.tech/api/v1';
  let base = (import.meta.env.VITE_API_BASE_URL || (import.meta.env.DEV ? 'http://127.0.0.1:8000/api/v1' : defaultProd)).trim();
  base = base.replace(/\/+$/, '');
  if (!base.endsWith('/api/v1')) {
    base = `${base}/api/v1`;
  }
  return base;
};

const API_BASE = getApiBase();

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
    if (response.status === 401 && token) {
      // Stale or invalid token - auto-purge to avoid stuck authentication
      removeAuthToken();
      removeCurrentUser();
      window.dispatchEvent(new CustomEvent('recell-auth-expired'));
    }
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

  // Catalog & Categories
  getCategories: (all = false) => request(`/catalog/categories/?all=${all}`),
  createCategory: (data) => request('/catalog/categories/', { method: 'POST', body: JSON.stringify(data) }),
  updateCategory: (id, data) => request(`/catalog/categories/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteCategory: (id) => request(`/catalog/categories/${id}/`, { method: 'DELETE' }),

  getBrands: (includeModels = false, all = false, categoryId = null) => 
    request(`/catalog/brands/?include_models=${includeModels}&all=${all}${categoryId ? `&category=${categoryId}` : ''}`),
  createBrand: (data) => request('/catalog/brands/', { method: 'POST', body: JSON.stringify(data) }),
  updateBrand: (id, data) => request(`/catalog/brands/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteBrand: (id) => request(`/catalog/brands/${id}/`, { method: 'DELETE' }),

  getSeries: (brandId) => request(`/catalog/series/?${brandId ? `brand=${brandId}` : ''}`),
  createSeries: (data) => request('/catalog/series/', { method: 'POST', body: JSON.stringify(data) }),
  updateSeries: (id, data) => request(`/catalog/series/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteSeries: (id) => request(`/catalog/series/${id}/`, { method: 'DELETE' }),

  getModels: (brandId, all = false, seriesId = null) => 
    request(`/catalog/models/?${brandId ? `brand=${brandId}&` : ''}${seriesId ? `series=${seriesId}&` : ''}all=${all}`),
  getModelDetail: (id) => request(`/catalog/models/${id}/`),
  createModel: (data) => request('/catalog/models/', { method: 'POST', body: JSON.stringify(data) }),
  updateModel: (id, data) => request(`/catalog/models/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteModel: (id) => request(`/catalog/models/${id}/`, { method: 'DELETE' }),

  getCMSSections: () => request('/catalog/cms/sections/'),
  updateCMSSection: (data) => request('/catalog/cms/sections/', { method: 'POST', body: JSON.stringify(data) }),

  getVariants: (modelId, all = false) => request(`/catalog/variants/?${modelId ? `model=${modelId}&` : ''}all=${all}`),
  createVariant: (data) => request('/catalog/variants/', { method: 'POST', body: JSON.stringify(data) }),
  updateVariant: (id, data) => request(`/catalog/variants/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteVariant: (id) => request(`/catalog/variants/${id}/`, { method: 'DELETE' }),

  // Valuation & Dynamic Pricing
  getConditionCategories: (all = false, brandId = '') => request(`/valuation/conditions/?all=${all}${brandId ? `&brand=${brandId}` : ''}`),
  createConditionCategory: (data) => request('/valuation/conditions/', { method: 'POST', body: JSON.stringify(data) }),
  updateConditionCategory: (id, data) => request(`/valuation/conditions/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteConditionCategory: (id) => request(`/valuation/conditions/${id}/`, { method: 'DELETE' }),
  copyQuestionsFromBrand: (sourceBrandId, targetBrandId, markMandatory = true) =>
    request('/valuation/conditions/copy-from-brand/', {
      method: 'POST',
      body: JSON.stringify({
        source_brand_id: sourceBrandId ? Number(sourceBrandId) : null,
        target_brand_id: Number(targetBrandId),
        mark_mandatory: markMandatory
      })
    }),

  getConditionOptions: (categoryId, all = false) => request(`/valuation/options/?${categoryId ? `category=${categoryId}&` : ''}all=${all}`),
  createConditionOption: (data) => request('/valuation/options/', { method: 'POST', body: JSON.stringify(data) }),
  updateConditionOption: (id, data) => request(`/valuation/options/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteConditionOption: (id) => request(`/valuation/options/${id}/`, { method: 'DELETE' }),

  calculateEstimate: (variantId, selectedCodes) => 
    request('/valuation/estimate/', {
      method: 'POST',
      body: JSON.stringify({ variant_id: variantId, selected_option_codes: selectedCodes })
    }),
  previewValuation: (variantId, selectedCodes) => 
    request('/valuation/pricing/preview/', {
      method: 'POST',
      body: JSON.stringify({ variant_id: variantId, selected_option_codes: selectedCodes })
    }),
  getPriceHistory: (variantId) => request(`/valuation/pricing/history/${variantId ? `?variant=${variantId}` : ''}`),

  // Sales
  submitSale: (payload) => request('/sales/', { method: 'POST', body: JSON.stringify(payload) }),
  getSales: (params = {}) => {
    const query = new URLSearchParams(params).toString();
    return request(`/sales/${query ? `?${query}` : ''}`);
  },
  getSaleDetail: (idOrCode) => request(`/sales/${idOrCode}/`),
  acceptOffer: (id) => request(`/sales/${id}/accept-offer/`, { method: 'POST' }),
  rejectOffer: (id) => request(`/sales/${id}/reject-offer/`, { method: 'POST' }),
  markDeviceCollected: (id) => request(`/sales/${id}/mark-collected/`, { method: 'POST' }),
  assignPickup: (id, payload) => request(`/sales/${id}/schedule-pickup/`, { method: 'POST', body: JSON.stringify(payload) }),
  shiftPickupToNextDay: (id, payload = {}) => request(`/sales/${id}/shift-next-day/`, { method: 'POST', body: JSON.stringify(payload) }),
  lookupPincode: (pincode) => request(`/sales/pincode-lookup/?pincode=${pincode}`),
  transferOwnership: (id, payload) => request(`/sales/${id}/transfer-ownership/`, { method: 'POST', body: JSON.stringify(payload) }),
  adminApproveFinalOffer: (id, payload) => request(`/sales/${id}/approve-final-offer/`, { method: 'POST', body: JSON.stringify(payload) }),

  // Inspection
  recordInspection: (payload) => request('/inspections/', { method: 'POST', body: JSON.stringify(payload) }),

  // Payments (Manual Payout Proof & UTR)
  getPaymentQR: (saleId) => request(`/payments/qr/${saleId}/`),
  recordPayout: (payload) => request('/payments/record-payout/', { method: 'POST', body: JSON.stringify(payload) }),
  getPaymentsList: (params = {}) => {
    const query = new URLSearchParams(params).toString();
    return request(`/payments/${query ? `?${query}` : ''}`);
  },
  getPaymentReceipt: (saleCode) => request(`/payments/receipt/${saleCode}/`),
  
  // Health & Keep-Alive Ping
  pingHealth: () => request('/health/').catch(() => null),
};
