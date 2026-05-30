import { useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api/axios';
import LoginFormImg from '../assets/img1.webp';

const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');

    try {
      const response = await api.post('/auth/login', {
        email: email,
        password: password
      });
      
      localStorage.setItem('token', response.data.access_token);
      window.location.href = '/dashboard'; 
    } catch (err) {
      setError('Email o contraseña incorrectos');
    }
  };

  return (
    <div className="relative min-h-screen w-full overflow-hidden flex items-center justify-center">
      {/* Fondo con gradiente SVG */}
      <svg 
        className="fixed inset-0 w-full h-full -z-10"
        viewBox="0 0 1600 900"
        preserveAspectRatio="xMidYMid slice"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <linearGradient id="linearGradientId" gradientTransform="rotate(90 0.5 0.5)">
            <stop offset="0%" stopColor="rgba(158, 158, 158, 1)" />
            <stop offset="100%" stopColor="rgba(255, 255, 255, 1)" />
          </linearGradient>
        </defs>
        <rect width="1600" height="900" fill="url(#linearGradientId)" />
      </svg>

      {/* Contenedor del formulario */}
      <div className="relative z-20">
        <div className="flex flex-col items-center justify-center p-4">
          <div className="flex shadow-2xl rounded-md overflow-hidden bg-white/90 backdrop-blur-sm">
            {/* Lado izquierdo – Formulario */}
            <div
              className="flex flex-wrap content-center justify-center bg-white p-10"
              style={{ width: '24rem', height: '32rem' }}
            >
              <div className="w-72">
                <h1 className="text-xl font-bold text-center">Welcome back</h1>
                <p className="text-gray-500 text-center">
                  Por favor introduce tus datos
                </p>

                {error && (
                  <div className="bg-red-50 text-red-600 p-2 rounded-md mt-3 text-xs border border-red-100 text-center">
                    {error}
                  </div>
                )}

                <form onSubmit={handleLogin} className="mt-4">
                  <div className="mb-3">
                    <label className="mb-2 block text-xs font-semibold">
                      Email
                    </label>
                    <input
                      type="email"
                      placeholder="Escribe tu email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="block w-full rounded-md border border-gray-300 focus:border-purple-700 focus:outline-none focus:ring-1 focus:ring-purple-700 py-1 px-1.5 text-gray-500"
                    />
                  </div>

                  <div className="mb-3">
                    <label className="mb-2 block text-xs font-semibold">
                      Contraseña
                    </label>
                    <input
                      type="password"
                      placeholder="*****"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="block w-full rounded-md border border-gray-300 focus:border-purple-700 focus:outline-none focus:ring-1 focus:ring-purple-700 py-1 px-1.5 text-gray-500"
                    />
                  </div>

                  <div className="mb-3">
                    <button
                      type="submit"
                      className="mb-1.5 block w-full text-center text-white bg-purple-700 hover:bg-purple-900 px-2 py-1.5 rounded-md transition-colors cursor-pointer"
                    >
                      Iniciar sesión
                    </button>
                    <a
                      href="https://github.com"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center justify-center w-full border border-gray-300 hover:border-gray-500 hover:bg-gray-50 px-2 py-1.5 rounded-md transition-all no-underline text-gray-700"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        width="16"
                        height="16"
                        fill="currentColor"
                        className="bi bi-github mr-2"
                        viewBox="0 0 16 16"
                      >
                        <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8" />
                      </svg>
                      <span className="text-sm font-medium">
                        Visita nuestro Github
                      </span>
                    </a>
                  </div>
                </form>

                <div className="text-center">
                  <span className="text-xs text-gray-500 font-semibold">
                    ¿No tienes cuenta?
                  </span>
                  <Link
                    to="/register"
                    className="no-underline hover:underline hover:text-purple-500 transition-all text-xs font-semibold text-purple-700 ml-1 cursor-pointer"
                  >
                    Regístrate
                  </Link>
                </div>
              </div>
            </div>

            {/* Lado derecho – Imagen */}
            <div
              className="hidden md:flex flex-wrap content-center justify-center bg-gray-100"
              style={{ width: '24rem', height: '32rem' }}
            >
              <img
                className="w-full h-full object-cover"
                src={LoginFormImg}
                alt="background"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;