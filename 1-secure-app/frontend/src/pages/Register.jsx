import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import api from '../api/axios';
import RegisterFormImg from '../assets/img1.webp';

const Register = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const navigate = useNavigate();

  const validatePassword = (pass) => {
    const hasUpperCase = /[A-Z]/.test(pass);
    const hasNumber = /[0-9]/.test(pass);
    if (pass.length < 8) return "Mínimo 8 caracteres.";
    if (!hasUpperCase) return "Falta una mayúscula.";
    if (!hasNumber) return "Falta un número.";
    return null;
  };

const handleRegister = async (e) => {
    e.preventDefault();
    setError('');

    const passwordError = validatePassword(password);
    if (passwordError) return setError(passwordError);
    if (password !== confirmPassword) return setError('Las contraseñas no coinciden');

    try {
      await api.post('/auth/register', { email, password });
      setSuccess(true);
      setTimeout(() => navigate('/login'), 2000);
    } catch (err) {
      const errorDetail = err.response?.data?.detail;
      
      // 1. Si Pydantic devuelve un Array de errores de validación (ej. email mal formado)
      if (Array.isArray(errorDetail)) {
        // Extraemos solo el mensaje (msg) del primer error de la lista
        setError(`Error de formato: ${errorDetail[0].msg}`);
      } 
      // 2. Si es un error manual de tu backend (String) (ej. "El correo ya existe")
      else if (typeof errorDetail === 'string') {
        setError(errorDetail);
      } 
      // 3. Fallback genérico por si se cae el servidor o no hay internet
      else {
        setError('Error en el registro. Inténtalo de nuevo.');
      }
    }
  };

  return (
    <div className="relative min-h-screen w-full overflow-hidden flex items-center justify-center">
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

      <div className="relative z-20">
        <div className="flex flex-col items-center justify-center p-4">
          <div className="flex shadow-2xl rounded-md overflow-hidden bg-white/90 backdrop-blur-sm">
            {/* Lado izquierdo – Formulario */}
            <div
              className="flex flex-wrap content-center justify-center bg-white p-10"
              style={{ width: '24rem', height: '32rem' }}
            >
              <div className="w-72">
                <h1 className="text-xl font-bold text-center">Crea tu cuenta</h1>
                <p className="text-gray-500 text-center">
                  Únete a nosotros
                </p>

                {error && (
                  <div className="bg-red-50 text-red-600 p-2 rounded-md mt-3 text-xs border border-red-100 text-center">
                    {error}
                  </div>
                )}
                {success && (
                  <div className="bg-green-50 text-green-600 p-2 rounded-md mt-3 text-xs border border-green-100 text-center">
                    ¡Registro exitoso! Redirigiendo...
                  </div>
                )}

                <form onSubmit={handleRegister} className="mt-4">
                  {/* Campo Nombre – decorativo, no afecta al registro */}
                  <div className="mb-2">
                    <label className="mb-1 block text-xs font-semibold">
                      Nombre
                    </label>
                    <input
                      type="text"
                      placeholder="Escribe tu nombre"
                      className="block w-full rounded-md border border-gray-300 focus:border-purple-700 focus:outline-none focus:ring-1 focus:ring-purple-700 py-1 px-1.5 text-gray-500 text-sm"
                    />
                  </div>

                  <div className="mb-2">
                    <label className="mb-1 block text-xs font-semibold">
                      Email
                    </label>
                    <input
                      type="email"
                      placeholder="Escribe tu email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="block w-full rounded-md border border-gray-300 focus:border-purple-700 focus:outline-none focus:ring-1 focus:ring-purple-700 py-1 px-1.5 text-gray-500 text-sm"
                    />
                  </div>

                  <div className="mb-2">
                    <label className="mb-1 block text-xs font-semibold">
                      Contraseña
                    </label>
                    <input
                      type="password"
                      placeholder="*****"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      className="block w-full rounded-md border border-gray-300 focus:border-purple-700 focus:outline-none focus:ring-1 focus:ring-purple-700 py-1 px-1.5 text-gray-500 text-sm"
                    />
                  </div>

                  <div className="mb-4">
                    <label className="mb-1 block text-xs font-semibold">
                      Repetir contraseña
                    </label>
                    <input
                      type="password"
                      placeholder="*****"
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      className="block w-full rounded-md border border-gray-300 focus:border-purple-700 focus:outline-none focus:ring-1 focus:ring-purple-700 py-1 px-1.5 text-gray-500 text-sm"
                    />
                  </div>

                  <div className="mb-4">
                    <button
                      type="submit"
                      className="mb-1.5 block w-full text-center text-white bg-purple-700 hover:bg-purple-900 px-2 py-1.5 rounded-md transition-colors font-semibold cursor-pointer"
                    >
                      Registrarse
                    </button>
                  </div>
                </form>

                <div className="text-center">
                  <span className="text-xs text-gray-500 font-semibold">
                    ¿Ya tienes cuenta?
                  </span>
                  <Link
                    to="/login"
                    className="no-underline hover:underline hover:text-purple-500 transition-all text-xs font-semibold text-purple-700 ml-1 cursor-pointer"
                  >
                    Inicia sesión
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
                src={RegisterFormImg}
                alt="background"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Register;