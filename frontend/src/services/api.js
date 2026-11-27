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
  const isAuthEndpoint = endpoint.includes('/auth/login') || endpoint.includes('/auth/register');
  const token = !isAuthEndpoint ? getAuthToken() : null;
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
    const isAuthError = response.status === 401 || (response.status === 403 && (
      data.detail === 'Invalid token' ||
      data.detail === 'Token has expired' ||
      data.detail?.includes('authentication')
    ));

    if (isAuthError && getAuthToken()) {
      // Stale or invalid token - auto-purge to avoid stuck authentication
      removeAuthToken();
      removeCurrentUser();
      window.dispatchEvent(new CustomEvent('recell-auth-expired'));
    }
    let errorMsg = data.detail || data.message || data.error;
    if (!errorMsg && typeof data === 'object' && data !== null) {
      const entries = Object.entries(data);
      if (entries.length > 0) {
        const [field, val] = entries[0];
        const valText = Array.isArray(val) ? val.join(', ') : (typeof val === 'string' ? val : JSON.stringify(val));
        errorMsg = field === 'detail' || field === 'non_field_errors' ? valText : `${field}: ${valText}`;
      }
    }
    errorMsg = errorMsg || (response.statusText ? `${response.status} ${response.statusText}` : 'API Request Failed');
    throw new Error(typeof errorMsg === 'string' ? errorMsg : JSON.stringify(errorMsg));
  }
  return data;
}

// Lightweight SWR (Stale-While-Revalidate) Cache for read-only catalog endpoints
const SWR_TTL_MS = 5 * 60 * 1000; // 5 minutes cache

async function cachedRequest(endpoint, options = {}, ttlMs = SWR_TTL_MS) {
  const cacheKey = `dolly_swr_${endpoint}`;
  try {
    const cachedItem = sessionStorage.getItem(cacheKey);
    if (cachedItem) {
      const { data, timestamp } = JSON.parse(cachedItem);
      const isFresh = (Date.now() - timestamp) < ttlMs;
      // If stale, revalidate in background without blocking caller
      if (!isFresh) {
        request(endpoint, options).then((freshData) => {
          try {
            sessionStorage.setItem(cacheKey, JSON.stringify({ data: freshData, timestamp: Date.now() }));
          } catch (e) {}
        }).catch(() => {});
      }
      return data;
    }
  } catch (e) {
    // sessionStorage disabled or unavailable
  }

  const freshData = await request(endpoint, options);
  try {
    sessionStorage.setItem(cacheKey, JSON.stringify({ data: freshData, timestamp: Date.now() }));
  } catch (e) {}
  return freshData;
}

export const clearCatalogCache = () => {
  try {
    Object.keys(sessionStorage).forEach(key => {
      if (key.startsWith('dolly_swr_')) {
        sessionStorage.removeItem(key);
      }
    });
  } catch (e) {}
};

export const api = {
  // Auth
  login: (credentials) => request('/auth/login/', { method: 'POST', body: JSON.stringify(credentials) }),
  register: (payload) => request('/auth/register/', { method: 'POST', body: JSON.stringify(payload) }),
  getMe: () => request('/auth/me/'),
  getAgents: () => request('/auth/agents/'),
  createAgent: (data) => request('/auth/agents/', { method: 'POST', body: JSON.stringify(data) }),
  updateAgent: (id, data) => request(`/auth/agents/${id}/`, { method: 'PATCH', body: JSON.stringify(data) }),
  adminResetAgentPassword: (id, newPassword) => request(`/auth/agents/${id}/reset-password/`, { method: 'POST', body: JSON.stringify({ new_password: newPassword }) }),
  deleteAgent: (id) => request(`/auth/agents/${id}/`, { method: 'DELETE' }),
  changePassword: (data) => request('/auth/change-password/', { method: 'POST', body: JSON.stringify(data) }),
  getCustomers: (search = '') => request(`/auth/customers/${search ? `?search=${encodeURIComponent(search)}` : ''}`).then(res => (res && Array.isArray(res.results)) ? res.results : res),
  createCustomer: (data) => request('/auth/customers/', { method: 'POST', body: JSON.stringify(data) }),
  updateCustomer: (id, data) => request(`/auth/customers/${id}/`, { method: 'PATCH', body: JSON.stringify(data) }),
  adminResetCustomerPassword: (id, newPassword) => request(`/auth/customers/${id}/reset-password/`, { method: 'POST', body: JSON.stringify({ new_password: newPassword }) }),
  adminResetCustomerPasswordByPhone: (phone, newPassword) => request('/auth/customers/reset-password/', { method: 'POST', body: JSON.stringify({ phone, new_password: newPassword }) }),
  toggleCustomerActive: (id) => request(`/auth/customers/${id}/?action=toggle`, { method: 'DELETE' }),
  deleteCustomer: (id) => request(`/auth/customers/${id}/?action=delete`, { method: 'DELETE' }),

  // Catalog & Categories (Cached via SWR for instant 0ms front-page paints)
  getCatalogStats: () => request('/catalog/stats/'),
  getCategories: (all = false) => (all ? request(`/catalog/categories/?all=true`) : cachedRequest('/catalog/categories/?all=false')),
  createCategory: (data) => { clearCatalogCache(); return request('/catalog/categories/', { method: 'POST', body: JSON.stringify(data) }); },
  updateCategory: (id, data) => { clearCatalogCache(); return request(`/catalog/categories/${id}/`, { method: 'PUT', body: JSON.stringify(data) }); },
  deleteCategory: (id) => { clearCatalogCache(); return request(`/catalog/categories/${id}/`, { method: 'DELETE' }); },

  getBrands: (includeModels = false, all = false, categoryId = null) => {
    const url = `/catalog/brands/?include_models=${includeModels}&all=${all}${categoryId ? `&category=${categoryId}` : ''}`;
    return all || includeModels ? request(url) : cachedRequest(url);
  },
  createBrand: (data) => { clearCatalogCache(); return request('/catalog/brands/', { method: 'POST', body: JSON.stringify(data) }); },
  updateBrand: (id, data) => { clearCatalogCache(); return request(`/catalog/brands/${id}/`, { method: 'PUT', body: JSON.stringify(data) }); },
  deleteBrand: (id) => { clearCatalogCache(); return request(`/catalog/brands/${id}/`, { method: 'DELETE' }); },

  getSeries: (brandId) => cachedRequest(`/catalog/series/?${brandId ? `brand=${brandId}` : ''}`),
  createSeries: (data) => { clearCatalogCache(); return request('/catalog/series/', { method: 'POST', body: JSON.stringify(data) }); },
  updateSeries: (id, data) => { clearCatalogCache(); return request(`/catalog/series/${id}/`, { method: 'PUT', body: JSON.stringify(data) }); },
  deleteSeries: (id) => { clearCatalogCache(); return request(`/catalog/series/${id}/`, { method: 'DELETE' }); },

  getModels: (brandId, all = false, seriesId = null) => 
    request(`/catalog/models/?${brandId ? `brand=${brandId}&` : ''}${seriesId ? `series=${seriesId}&` : ''}all=${all}`).then(res => (res && Array.isArray(res.results)) ? res.results : res),
  getModelDetail: (id) => request(`/catalog/models/${id}/`),
  createModel: (data) => { clearCatalogCache(); return request('/catalog/models/', { method: 'POST', body: JSON.stringify(data) }); },
  updateModel: (id, data) => { clearCatalogCache(); return request(`/catalog/models/${id}/`, { method: 'PUT', body: JSON.stringify(data) }); },
  deleteModel: (id) => { clearCatalogCache(); return request(`/catalog/models/${id}/`, { method: 'DELETE' }); },

  getCMSSections: () => cachedRequest('/catalog/cms/sections/'),
  updateCMSSection: (data) => { clearCatalogCache(); return request('/catalog/cms/sections/', { method: 'POST', body: JSON.stringify(data) }); },
  getSystemSettings: () => request('/catalog/settings/'),
  updateSystemSettings: (data) => request('/catalog/settings/', { method: 'POST', body: JSON.stringify(data) }),

  getVariants: (modelId, all = false, brandId = null, seriesId = null) => 
    request(`/catalog/variants/?${modelId ? `model=${modelId}&` : ''}${brandId ? `brand=${brandId}&` : ''}${seriesId ? `series=${seriesId}&` : ''}all=${all}`).then(res => (res && Array.isArray(res.results)) ? res.results : res),
  createVariant: (data) => request('/catalog/variants/', { method: 'POST', body: JSON.stringify(data) }),
  updateVariant: (id, data) => request(`/catalog/variants/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteVariant: (id) => request(`/catalog/variants/${id}/`, { method: 'DELETE' }),
  bulkDeleteCatalog: (target, ids = [], all = false) => request('/catalog/bulk-delete/', { method: 'POST', body: JSON.stringify({ target, ids, all }) }),

  // Valuation & Dynamic Pricing
  // Initial Health Check (4 Yes/No Triage Questions)
  getTriageQuestions: (all = true) => request(`/valuation/triage-questions/?all=${all}`),
  createTriageQuestion: (data) => request('/valuation/triage-questions/', { method: 'POST', body: JSON.stringify(data) }),
  updateTriageQuestion: (id, data) => request(`/valuation/triage-questions/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteTriageQuestion: (id, permanent = false) => request(`/valuation/triage-questions/${id}/?permanent=${permanent}`, { method: 'DELETE' }),

  getConditionCategories: (all = false, brandId = '') => request(`/valuation/conditions/?all=${all}${brandId ? `&brand=${brandId}` : ''}`),
  createConditionCategory: (data) => request('/valuation/conditions/', { method: 'POST', body: JSON.stringify(data) }),
  updateConditionCategory: (id, data) => request(`/valuation/conditions/${id}/`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteConditionCategory: (id) => request(`/valuation/conditions/${id}/`, { method: 'DELETE' }),
  bulkDeleteValuation: (target, ids = [], all = false) => request('/valuation/bulk-delete/', { method: 'POST', body: JSON.stringify({ target, ids, all }) }),
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
    return request(`/sales/${query ? `?${query}` : ''}`).then(res => (res && Array.isArray(res.results)) ? res.results : res);
  },
  getSaleDetail: (idOrCode) => request(`/sales/${idOrCode}/`),
  getSaleByCode: (code) => request(`/sales/${code}/`),
  acceptOffer: (id) => request(`/sales/${id}/accept-offer/`, { method: 'POST' }),
  rejectOffer: (id) => request(`/sales/${id}/reject-offer/`, { method: 'POST' }),
  cancelOrder: (id, payload = {}) => request(`/sales/${id}/cancel/`, { method: 'POST', body: JSON.stringify(payload) }),
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
