import axios from 'axios';

const api = axios.create({
  baseURL: `${window.location.origin}/api`
});

// Interceptor para pegar el token en cada llamada
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {

    config.headers.Authorization = `Bearer ${token}`;
    console.log("Token enviado en la petición");
  } else {
    console.warn("No hay token en localStorage");
  }
  return config;
}, (error) => {
  return Promise.reject(error);
});

export default api;