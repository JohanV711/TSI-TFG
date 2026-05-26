import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import api from '../api/axios';

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
      setError(err.response?.data?.detail || 'Error en el registro');
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen bg-gray-50 px-4">
      <div className="max-w-md w-full bg-white p-8 rounded-2xl shadow-lg border border-gray-100">
        <h2 className="text-3xl font-bold text-center text-gray-900 mb-8">Secure App</h2>
        {error && <div className="bg-red-50 text-red-600 p-3 rounded-lg mb-4 text-sm text-center">{error}</div>}
        <form onSubmit={handleRegister} className="space-y-4">
          <input type="email" placeholder="Email" required className="w-full px-4 py-3 rounded-xl border" value={email} onChange={(e) => setEmail(e.target.value)} />
          <input type="password" placeholder="Contraseña" required className="w-full px-4 py-3 rounded-xl border" value={password} onChange={(e) => setPassword(e.target.value)} />
          <input type="password" placeholder="Confirmar" required className="w-full px-4 py-3 rounded-xl border" value={confirmPassword} onChange={(e) => setConfirmPassword(e.target.value)} />
          <button type="submit" className="w-full bg-green-600 text-white py-3 rounded-xl font-semibold">Registrarse</button>
        </form>
        <p className="mt-6 text-center text-sm"><Link to="/login" className="text-blue-600">Volver al Login</Link></p>
      </div>
    </div>
  );
};

export default Register;