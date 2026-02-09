// admin/src/services/api.js
import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to requests
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Handle 401 errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Auth Service
export const authService = {
  login: async (email, password) => {
    const response = await api.post('/api/auth/login', { email, password });
    if (response.data.success) {
      localStorage.setItem('token', response.data.data.token);
      localStorage.setItem('user', JSON.stringify(response.data.data.user));
    }
    return response.data;
  },
  
  logout: () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  },
  
  getCurrentUser: () => {
    const user = localStorage.getItem('user');
    return user ? JSON.parse(user) : null;
  },
};

// Campaign Service
export const campaignService = {
  getAll: async () => {
    const response = await api.get('/api/campaigns');
    return response.data.data;
  },
  
  getById: async (id) => {
    const response = await api.get(`/api/campaigns/${id}`);
    return response.data.data;
  },
  
  create: async (campaignData) => {
    const response = await api.post('/api/campaigns', campaignData);
    return response.data;
  },
  
  update: async (id, campaignData) => {
    const response = await api.put(`/api/campaigns/${id}`, campaignData);
    return response.data;
  },
  
  delete: async (id) => {
    const response = await api.delete(`/api/campaigns/${id}`);
    return response.data;
  },
};

// Donation Service
export const donationService = {
  getAll: async () => {
    const response = await api.get('/api/donations/my-donations');
    return response.data.data;
  },
};

// Dashboard Service
export const dashboardService = {
  getStats: async () => {
    try {
      const [campaigns, donations] = await Promise.all([
        api.get('/api/campaigns'),
        api.get('/api/donations/my-donations')
      ]);
      
      return {
        totalCampaigns: campaigns.data.count || 0,
        activeCampaigns: campaigns.data.data.filter(c => c.status === 'active').length,
        totalDonations: donations.data.data.length,
        totalAmount: donations.data.data.reduce((sum, d) => sum + parseFloat(d.amount), 0),
      };
    } catch (error) {
      console.error('Error fetching stats:', error);
      return {
        totalCampaigns: 0,
        activeCampaigns: 0,
        totalDonations: 0,
        totalAmount: 0,
      };
    }
  },
};

export default api;