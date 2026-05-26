import { useEffect, useState, useRef } from 'react';
import api from '../api/axios';

const Dashboard = () => {
  const [albums, setAlbums] = useState([]);
  const [newAlbumName, setNewAlbumName] = useState('');
  const [selectedFile, setSelectedFile] = useState(null);
  const [uploadAlbumId, setUploadAlbumId] = useState('');
  const [error, setError] = useState('');
  const [selectedImage, setSelectedImage] = useState(null);
  
  const fileInputRef = useRef(null);

  // --- FUNCIONES EXISTENTES (SIN CAMBIOS) ---
  const fetchAlbums = async () => {
    try {
      const resAlbums = await api.get('/albums/');
      const albumsData = resAlbums.data;

      const albumsWithPhotos = await Promise.all(
        albumsData.map(async (album) => {
          try {
            const resPhotos = await api.get(`/photos?album_id=${album.album_id}`);
            return { ...album, images: resPhotos.data };
          } catch (err) {
            return { ...album, images: [] };
          }
        })
      );
      setAlbums(albumsWithPhotos);
    } catch (err) {
      console.error("Error cargando datos", err);
      setError('No se pudieron cargar los álbumes.');
    }
  };

  useEffect(() => { fetchAlbums(); }, []);

  const handleCreateAlbum = async (e) => {
    e.preventDefault();
    if (!newAlbumName.trim()) return;
    try {
      await api.post('/albums/', { name: newAlbumName });
      setNewAlbumName('');
      fetchAlbums();
    } catch (err) { setError('Error al crear álbum'); }
  };

  const handleUploadImage = async (e) => {
    e.preventDefault();
    if (!selectedFile || !uploadAlbumId) return setError('Selecciona imagen y álbum');
    setError('');

    const formData = new FormData();
    formData.append('file', selectedFile);

    try {
      const url = `/photos?album_id=${uploadAlbumId}&title=${encodeURIComponent(selectedFile.name)}`;
      const response = await api.post(url, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
    
      setSelectedFile(null);
      if (fileInputRef.current) { fileInputRef.current.value = ""; }
      fetchAlbums(); 
      alert("Imagen subida correctamente");
    } catch (err) {
      if (err.response) {
        setError(`Error ${err.response.status}: ${JSON.stringify(err.response.data.detail)}`);
      } else if (err.request) {
        setError("Fallo de red: El servidor no responde.");
      } else {
        setError("Error interno en el navegador.");
      }
    }
  };

  // --- NUEVAS FUNCIONES DE ELIMINACIÓN ---
  const handleDeletePhoto = async (photoId) => {
    if (!window.confirm("¿Estás seguro de que quieres eliminar esta foto?")) return;
    try {
      await api.delete(`/photos/${photoId}`);
      fetchAlbums(); 
    } catch (err) {
      setError('No se pudo eliminar la foto.');
    }
  };

  const handleDeleteAlbum = async (albumId) => {
    if (!window.confirm("¿Eliminar álbum? Se borrarán todas las fotos de su interior.")) return;
    try {
      await api.delete(`/albums/${albumId}`);
      fetchAlbums(); 
    } catch (err) {
      setError('Error al eliminar el álbum.');
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-6xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-gray-800">Gestor de Imágenes Seguro</h1>
          <button onClick={() => { localStorage.removeItem('token'); window.location.href='/login'; }} className="text-red-500 font-bold">Cerrar Sesión</button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-12">
          <div className="bg-white p-6 rounded-2xl shadow-sm border">
            <h2 className="font-bold mb-4">Nuevo Álbum</h2>
            <form onSubmit={handleCreateAlbum} className="flex gap-2">
              <input type="text" className="flex-1 border p-2 rounded-lg" value={newAlbumName} onChange={(e)=>setNewAlbumName(e.target.value)} placeholder="Nombre..." />
              <button className="bg-blue-600 text-white px-4 py-2 rounded-lg">Crear</button>
            </form>
          </div>
          <div className="bg-white p-6 rounded-2xl shadow-sm border">
            <h2 className="font-bold mb-4">Subir Imagen</h2>
            <form onSubmit={handleUploadImage} className="space-y-3">
              <select className="w-full border p-2 rounded-lg" onChange={(e)=>setUploadAlbumId(e.target.value)} value={uploadAlbumId}>
                <option value="">Selecciona Álbum...</option>
                {albums.map(a => <option key={a.album_id} value={a.album_id}>{a.name}</option>)}
              </select>
              <input 
                type="file" 
                ref={fileInputRef}
                className="w-full text-sm" 
                onChange={(e)=>setSelectedFile(e.target.files[0])} 
              />
              <button className="w-full bg-green-600 text-white py-2 rounded-lg font-bold">Subir a la Nube</button>
            </form>
          </div>
        </div>

        {error && <p className="text-red-500 mb-4 text-center font-bold">{error}</p>}

        <div className="space-y-12">
          {albums.map(album => (
            <div key={album.album_id} className="bg-white p-6 rounded-2xl shadow-sm border">
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-2xl font-bold text-gray-700 flex items-center gap-2">
                  📁 {album.name} 
                  <span className="text-sm font-normal text-gray-400 bg-gray-100 px-2 py-1 rounded-full">
                    {album.images?.length || 0} fotos
                  </span>
                </h2>
                <button 
                  onClick={() => handleDeleteAlbum(album.album_id)}
                  className="text-red-400 hover:text-red-600 text-sm font-medium transition-colors"
                >
                  🗑️ Eliminar Álbum
                </button>
              </div>
      
              {album.images && album.images.length > 0 ? (
                <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                  {album.images.map(img => (
                    <div key={img.photo_id}
                    className="group relative aspect-square bg-gray-50 rounded-xl overflow-hidden border border-gray-100 hover:shadow-md transition-shadow">
                      <img 
                        src={`http://localhost:8000/api/photos/${img.photo_id}/thumbnail`} 
                        alt={img.title || "Imagen de álbum"}
                        className="w-full h-full object-cover cursor-pointer"
                        onClick={() => setSelectedImage(img)} 
                        onError={(e) => { 
                          e.target.onerror = null; 
                          e.target.src = 'https://via.placeholder.com/150?text=Error+Carga'; 
                        }}
                      />
                      
                      {/* Botón para eliminar foto */}
                      <button 
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDeletePhoto(img.photo_id);
                        }}
                        className="absolute top-2 right-2 bg-white/90 hover:bg-red-50 text-red-600 p-1.5 rounded-lg shadow-sm opacity-0 group-hover:opacity-100 transition-opacity z-10"
                      >
                        🗑️
                      </button>

                      <div className="absolute bottom-0 left-0 right-0 bg-black/40 p-2 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
                        <span className="text-white text-[10px] truncate block">{img.title}</span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-gray-400 italic text-sm">Este álbum aún está vacío. ¡Sube alguna foto!</p>
              )}
            </div>
          ))}
        </div>
      </div>

      {selectedImage && (
        <div 
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4"
          onClick={() => setSelectedImage(null)}
        >
          <div className="relative max-w-5xl w-full flex flex-col items-center">
            <button 
              className="absolute -top-10 right-0 text-white text-4xl hover:text-gray-300"
              onClick={() => setSelectedImage(null)}
            >
              &times;
            </button>            
            <img   
              src={`http://localhost:8000/api/photos/${selectedImage.photo_id}/thumbnail`} 
              alt={selectedImage.title}
              className="max-w-full max-h-[80vh] object-contain shadow-2xl rounded-lg border-2 border-white/20"
              onClick={(e) => e.stopPropagation()} 
              onError={(e) => {
                console.log("Error en el modal con ID:", selectedImage.photo_id);
                e.target.src = `http://localhost:8000/api/photos/${selectedImage.photo_id}/file`;
              }}
            />            
            {selectedImage.title && (
              <p className="text-white mt-4 text-lg font-medium">{selectedImage.title}</p>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default Dashboard;