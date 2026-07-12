import { useEffect, useState, useRef, useCallback } from 'react';
import api from '../api/axios';

const Dashboard = () => {
  const [albums, setAlbums] = useState([]);
  const [newAlbumName, setNewAlbumName] = useState('');
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploadAlbumId, setUploadAlbumId] = useState('');
  const [error, setError] = useState('');
  const [selectedImage, setSelectedImage] = useState(null);
  const [loading, setLoading] = useState(true);
  const fileInputRef = useRef(null);
  const blobUrlsRef = useRef([]);

  const [showCreateAlbum, setShowCreateAlbum] = useState(false);
  const [showUploadImage, setShowUploadImage] = useState(false);
  
  const [deleteConfirm, setDeleteConfirm] = useState({ show: false, type: '', id: null, message: '' });

  useEffect(() => {
    return () => {
      blobUrlsRef.current.forEach(url => URL.revokeObjectURL(url));
    };
  }, []);

  const fetchAlbums = useCallback(async () => {
    setLoading(true);
    try {
      const resAlbums = await api.get('/albums/');
      const albumsWithPhotos = await Promise.all(
        resAlbums.data.map(async (album) => {
          try {
            const resPhotos = await api.get(`/photos?album_id=${album.album_id}`);
            const photosWithUrls = await Promise.all(
              resPhotos.data.map(async (photo) => {
                try {
                  const res = await api.get(`/photos/${photo.photo_id}/thumbnail`, {
                    responseType: 'blob'
                  });
                  const blobUrl = URL.createObjectURL(res.data);
                  blobUrlsRef.current.push(blobUrl);
                  return { ...photo, blobUrl };
                } catch {
                  return { ...photo, blobUrl: null };
                }
              })
            );
            return { ...album, images: photosWithUrls };
          } catch {
            return { ...album, images: [] };
          }
        })
      );
      setAlbums(albumsWithPhotos);
    } catch {
      setError('No se pudieron cargar los álbumes.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchAlbums(); }, [fetchAlbums]);

  const handleCreateAlbum = async (e) => {
    e.preventDefault();
    if (!newAlbumName.trim()) return;
    try {
      await api.post('/albums/', { name: newAlbumName });
      setNewAlbumName('');
      setShowCreateAlbum(false);
      fetchAlbums();
    } catch { setError('Error al crear álbum'); }
  };

  const handleUploadImage = async (e) => {
    e.preventDefault();
    if (!selectedFile || !uploadAlbumId) return setError('Selecciona imagen y álbum');
    setError('');
    const formData = new FormData();
    formData.append('file', selectedFile);
    try {
      await api.post(
        `/photos?album_id=${uploadAlbumId}&title=${encodeURIComponent(selectedFile.name)}`,
        formData,
        { headers: { 'Content-Type': 'multipart/form-data' } }
      );
      setSelectedFile(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
      setUploadAlbumId('');
      setShowUploadImage(false);
      fetchAlbums();
    } catch (err) {
      setError(err.response ? `Error ${err.response.status}: ${JSON.stringify(err.response.data.detail)}` : 'Fallo de red.');
    }
  };

  const handleDeletePhotoRequest = (photoId) => {
    setDeleteConfirm({ show: true, type: 'photo', id: photoId, message: '¿Estás seguro de que deseas eliminar esta fotografía de forma permanente?' });
  };

  const handleDeleteAlbumRequest = (albumId) => {
    setDeleteConfirm({ show: true, type: 'album', id: albumId, message: '¿Estás seguro de que deseas eliminar este álbum? Todas las fotos que contenga serán destruidas.' });
  };

  const executeDelete = async () => {
    try {
      if (deleteConfirm.type === 'photo') {
        await api.delete(`/photos/${deleteConfirm.id}`);
      } else if (deleteConfirm.type === 'album') {
        await api.delete(`/albums/${deleteConfirm.id}`);
      }
      fetchAlbums();
    } catch {
      setError(`No se pudo eliminar el ${deleteConfirm.type === 'photo' ? 'archivo' : 'álbum'}.`);
    } finally {
      setDeleteConfirm({ show: false, type: '', id: null, message: '' });
    }
  };

  const openModal = async (img) => {
    try {
      const res = await api.get(`/photos/${img.photo_id}/file`, { responseType: 'blob' });
      const blobUrl = URL.createObjectURL(res.data);
      blobUrlsRef.current.push(blobUrl);
      setSelectedImage({ ...img, fullBlobUrl: blobUrl });
    } catch {
      setSelectedImage({ ...img, fullBlobUrl: img.blobUrl });
    }
  };

  const totalPhotos = albums.reduce((acc, a) => acc + (a.images?.length || 0), 0);

  return (
    <div className="relative min-h-screen w-full overflow-hidden bg-gray-50">
      {/* Fondo gradiente claro */}
      <svg
        className="fixed inset-0 w-full h-full -z-10"
        viewBox="0 0 1600 900"
        preserveAspectRatio="xMidYMid slice"
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <linearGradient id="gradDashboard" gradientTransform="rotate(90 0.5 0.5)">
            <stop offset="0%" stopColor="rgba(158, 158, 158, 1)" />
            <stop offset="100%" stopColor="rgba(255, 255, 255, 1)" />
          </linearGradient>
        </defs>
        <rect width="1600" height="900" fill="url(#gradDashboard)" />
      </svg>

      {/* Contenido principal */}
      <div className="relative z-10 flex flex-col min-h-screen">
        {/* Header con logo a la izquierda */}
        <header className="flex items-center justify-between px-6 py-4 bg-white/80 backdrop-blur-sm border-b border-gray-200">
          <h1 className="text-2xl font-black tracking-widest uppercase text-gray-800">
            GALLERY<span className="text-purple-700">.</span>
          </h1>
          <div className="flex items-center gap-4">
            <button
              onClick={() => { localStorage.removeItem('token'); window.location.href = '/login'; }}
              className="text-sm font-medium text-white bg-red-600 hover:bg-red-700 px-4 py-2 rounded-md transition-colors"
            >
              Cerrar sesión
            </button>
          </div>
        </header>

        <main className="flex-grow container mx-auto px-4 py-8">
          {/* Menú de acciones */}
          <div className="flex items-center justify-center flex-wrap gap-3 mb-10">
            <button
              onClick={() => setShowCreateAlbum(true)}
              className="text-gray-700 border border-gray-300 bg-white hover:bg-gray-100 rounded-md text-sm font-medium px-5 py-2.5 transition-colors shadow-sm"
            >
              + Nuevo álbum
            </button>
            <button
              onClick={() => setShowUploadImage(true)}
              className="text-gray-700 border border-gray-300 bg-white hover:bg-gray-100 rounded-md text-sm font-medium px-5 py-2.5 transition-colors shadow-sm"
            >
              ↑ Subir foto
            </button>
            <div className="hidden md:flex items-center gap-4 text-xs text-gray-500 ml-4">
              <span><strong className="block text-gray-800 text-base font-bold">{albums.length}</strong>Álbumes</span>
              <span><strong className="block text-gray-800 text-base font-bold">{totalPhotos}</strong>Fotos</span>
            </div>
          </div>

          {/* Mensaje de error */}
          {error && (
            <div className="max-w-2xl mx-auto mb-8 bg-red-50 border border-red-200 text-red-600 px-4 py-3 text-sm text-center rounded-md">
              {error}
            </div>
          )}

          {/* Contenido: carga, vacío o álbumes */}
          {loading ? (
            <div className="text-center py-24 text-sm tracking-widest uppercase text-gray-400">
              Cargando colección...
            </div>
          ) : albums.length === 0 ? (
            <div className="border border-dashed border-gray-300 py-20 text-center text-sm tracking-widest uppercase text-gray-400 bg-white/50 rounded-xl">
              No hay álbumes — crea uno para empezar
            </div>
          ) : (
            albums.map(album => (
              <section key={album.album_id} className="mb-16">
                <div className="flex items-baseline justify-between border-b border-gray-200 pb-3 mb-4">
                  <div className="flex items-baseline gap-3">
                    <h2 className="text-2xl font-bold tracking-tight text-gray-800 uppercase">
                      {album.name}
                    </h2>
                    <span className="text-xs tracking-widest uppercase text-gray-400">
                      {album.images?.length || 0} fotos
                    </span>
                  </div>
                  <button
                    onClick={() => handleDeleteAlbumRequest(album.album_id)}
                    className="text-xs tracking-widest uppercase text-gray-400 hover:text-red-500 transition-colors"
                  >
                    Eliminar álbum
                  </button>
                </div>

                {album.images && album.images.length > 0 ? (
                  <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
                    {album.images.map(img => (
                      <div
                        key={img.photo_id}
                        // CAMBIO APLICADO: Añadido "aspect-square" para que todas las fotos sean cuadradas y uniformes
                        className="group relative overflow-hidden rounded-xl bg-gray-100 cursor-pointer shadow-sm aspect-square"
                        onClick={() => openModal(img)}
                      >
                        <img
                          src={img.blobUrl || '/placeholder.jpg'}
                          alt={img.title || 'Foto'}
                          loading="lazy"
                          className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-110"
                        />
                        {/* Overlay hover */}
                        <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-end justify-between p-3">
                          <span className="text-white text-xs font-light tracking-widest">
                            VER DETALLES
                          </span>
                          <button
                            onClick={(e) => { e.stopPropagation(); handleDeletePhotoRequest(img.photo_id); }}
                            className="w-7 h-7 bg-white/20 backdrop-blur-sm border border-white/30 text-white text-xs flex items-center justify-center hover:bg-red-500/80 transition-colors rounded-full"
                          >
                            X
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="border border-dashed border-gray-300 py-12 text-center text-xs tracking-widest uppercase text-gray-400 bg-white/50 rounded-xl">
                    Álbum vacío — sube la primera foto
                  </div>
                )}
              </section>
            ))
          )}
        </main>

        {/* Footer limpio y claro */}
        <footer className="bg-white/80 backdrop-blur-sm border-t border-gray-200 py-8 mt-auto">
          <div className="container mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="text-center md:text-left">
              <h2 className="text-gray-800 font-bold text-xl tracking-tighter mb-1">
                GALLERY<span className="text-purple-700">.</span>
              </h2>
              <p className="text-xs text-gray-500">
                Almacenamiento de fotos
              </p>
            </div>
            <div className="text-center text-xs text-gray-400">
              © 2026 TFG TSI
            </div>
            <div className="flex justify-center md:justify-end">
              <a
                href="https://github.com/JohanV711"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center px-4 py-2 bg-gray-100 hover:bg-gray-200 border border-gray-200 transition-all group rounded-md"
              >
                <svg
                  className="w-5 h-5 mr-2 fill-gray-500 group-hover:fill-gray-800 transition-colors"
                  viewBox="0 0 16 16"
                >
                  <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8" />
                </svg>
                <span className="text-sm font-medium text-gray-700 group-hover:text-gray-900 transition-colors">
                  Github Project
                </span>
              </a>
            </div>
          </div>
        </footer>

        {/* MODAL: Crear álbum */}
        {showCreateAlbum && (
          <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4" onClick={() => setShowCreateAlbum(false)}>
            <div className="bg-white rounded-2xl shadow-xl border border-gray-100 p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
              <h3 className="text-gray-800 text-lg font-bold mb-4">Nuevo álbum</h3>
              <form onSubmit={handleCreateAlbum} className="space-y-4">
                <input
                  type="text"
                  value={newAlbumName}
                  onChange={(e) => setNewAlbumName(e.target.value)}
                  placeholder="Nombre del álbum..."
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                />
                <div className="flex justify-end gap-3">
                  <button type="button" onClick={() => setShowCreateAlbum(false)} className="text-gray-500 hover:text-gray-700 text-sm">Cancelar</button>
                  <button type="submit" className="bg-purple-700 text-white px-4 py-2 text-sm font-semibold rounded-xl hover:bg-purple-800 transition-colors">Crear</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* MODAL: Subir imagen */}
        {showUploadImage && (
          <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4" onClick={() => setShowUploadImage(false)}>
            <div className="bg-white rounded-2xl shadow-xl border border-gray-100 p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
              <h3 className="text-gray-800 text-lg font-bold mb-4">Subir imagen</h3>
              <form onSubmit={handleUploadImage} className="space-y-4">
                <select
                  value={uploadAlbumId}
                  onChange={(e) => setUploadAlbumId(e.target.value)}
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm text-gray-500 outline-none focus:border-purple-500 focus:ring-2 focus:ring-purple-200 transition-all"
                >
                  <option value="">Selecciona álbum...</option>
                  {albums.map(a => (
                    <option key={a.album_id} value={a.album_id}>{a.name}</option>
                  ))}
                </select>
                <label className="block border border-dashed border-gray-300 rounded-xl px-4 py-2.5 text-sm text-gray-400 text-center cursor-pointer hover:border-purple-500 hover:text-purple-600 transition-colors">
                  {selectedFile ? `✓ ${selectedFile.name}` : '+ Seleccionar archivo'}
                  <input
                    type="file"
                    ref={fileInputRef}
                    accept="image/jpeg,image/png,image/webp"
                    onChange={(e) => setSelectedFile(e.target.files[0])}
                    className="hidden"
                  />
                </label>
                <div className="flex justify-end gap-3">
                  <button type="button" onClick={() => setShowUploadImage(false)} className="text-gray-500 hover:text-gray-700 text-sm">Cancelar</button>
                  <button
                    type="submit"
                    disabled={!selectedFile || !uploadAlbumId}
                    className="bg-purple-700 text-white px-4 py-2 text-sm font-semibold rounded-xl hover:bg-purple-800 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
                  >
                    Subir
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/*MODAL: Confirmación de Eliminación */}
        {deleteConfirm.show && (
          <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4" onClick={() => setDeleteConfirm({ show: false, type: '', id: null, message: '' })}>
            <div className="bg-white rounded-2xl shadow-xl border border-red-100 p-6 w-full max-w-sm transform transition-all" onClick={(e) => e.stopPropagation()}>
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center text-red-600">
                  <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
                </div>
                <h3 className="text-gray-900 text-lg font-bold">Confirmar acción</h3>
              </div>
              <p className="text-gray-500 text-sm mb-6 leading-relaxed">
                {deleteConfirm.message}
              </p>
              <div className="flex justify-end gap-3">
                <button 
                  onClick={() => setDeleteConfirm({ show: false, type: '', id: null, message: '' })} 
                  className="px-4 py-2 text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
                >
                  Cancelar
                </button>
                <button 
                  onClick={executeDelete} 
                  className="px-4 py-2 text-sm font-semibold text-white bg-red-600 hover:bg-red-700 rounded-xl transition-colors"
                >
                  Eliminar
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Modal de imagen (lightbox) */}
        {selectedImage && (
          <div
            className="fixed inset-0 z-[60] bg-black/90 backdrop-blur-md flex items-center justify-center p-8"
            onClick={() => setSelectedImage(null)}
          >
            <div className="relative flex flex-col items-center gap-4" onClick={(e) => e.stopPropagation()}>
              <button
                onClick={() => setSelectedImage(null)}
                className="absolute -top-12 right-0 text-xs font-bold tracking-widest uppercase text-white/70 hover:text-white transition-colors p-2"
              >
                Cerrar ✕
              </button>
              <img
                src={selectedImage.fullBlobUrl || selectedImage.blobUrl || '/placeholder.jpg'}
                alt={selectedImage.title}
                className="max-w-[85vw] max-h-[80vh] object-contain rounded-xl shadow-2xl"
              />
              {selectedImage.title && (
                <span className="text-xs font-medium tracking-widest uppercase text-white/90 bg-black/50 px-4 py-1.5 rounded-full mt-2">
                  {selectedImage.title}
                </span>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
