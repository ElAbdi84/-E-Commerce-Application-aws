// frontend/src/App.jsx
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

// Configuration de l'URL API (variable d'environnement)
//const API_URL = "/api";



// Configuration axios
//axios.defaults.baseURL = API_URL;

function App() {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(localStorage.getItem('token'));
  const [currentPage, setCurrentPage] = useState('home');

  // États pour l'authentification
  const [authForm, setAuthForm] = useState({
    email: '',
    password: '',
    username: '',
    firstName: '',
    lastName: ''
  });
  const [isLogin, setIsLogin] = useState(true);

  // États pour les produits
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState('');
  const [searchTerm, setSearchTerm] = useState('');

  // États pour le panier
  const [cart, setCart] = useState({ items: [], total: 0 });

  // États pour les commandes
  const [orders, setOrders] = useState([]);

  // État pour les messages
  const [message, setMessage] = useState({ type: '', text: '' });

  // Charger l'utilisateur au démarrage
  useEffect(() => {
    if (token) {
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
      fetchUserData();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  // Fonction pour afficher un message
  const showMessage = (type, text) => {
    setMessage({ type, text });
    setTimeout(() => setMessage({ type: '', text: '' }), 5000);
  };

  // Récupérer les données utilisateur
  const fetchUserData = async () => {
    try {
      const response = await axios.get('/api/auth/me');
      setUser(response.data);
    } catch (error) {
      console.error('Erreur récupération user:', error);
      handleLogout();
    }
  };

  // Connexion / Inscription
  const handleAuth = async (e) => {
    e.preventDefault();

    try {
      const endpoint = isLogin ? '/api/auth/login' : '/api/auth/register';
      const data = isLogin
        ? { email: authForm.email, password: authForm.password }
        : authForm;

      const response = await axios.post(endpoint, data);

      if (isLogin) {
        const { token, user } = response.data;
        localStorage.setItem('token', token);
        setToken(token);
        setUser(user);
        axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
        showMessage('success', 'Connexion réussie !');
        setCurrentPage('home');
      } else {
        showMessage('success', 'Compte créé ! Vous pouvez maintenant vous connecter.');
        setIsLogin(true);
      }

      // Reset form
      setAuthForm({
        email: '',
        password: '',
        username: '',
        firstName: '',
        lastName: ''
      });
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur authentification');
    }
  };

  // Déconnexion
  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
    setUser(null);
    delete axios.defaults.headers.common['Authorization'];
    setCurrentPage('home');
    showMessage('success', 'Déconnexion réussie');
  };

  // Charger les produits
  const fetchProducts = async () => {
    try {
      const params = {};
      if (selectedCategory) params.category = selectedCategory;
      if (searchTerm) params.search = searchTerm;

      const response = await axios.get('/api/products', { params });
      setProducts(response.data);
    } catch (error) {
      showMessage('error', 'Erreur chargement produits');
    }
  };

  // Charger les catégories
  const fetchCategories = async () => {
    try {
      const response = await axios.get('/api/categories');
      setCategories(response.data);
    } catch (error) {
      showMessage('error', 'Erreur chargement catégories');
    }
  };

  // Charger le panier
  const fetchCart = async () => {
    if (!token) return;

    try {
      const response = await axios.get('/api/cart');
      setCart(response.data);
    } catch (error) {
      showMessage('error', 'Erreur chargement panier');
    }
  };

  // Ajouter au panier
  const addToCart = async (productId) => {
    if (!token) {
      showMessage('error', 'Veuillez vous connecter');
      setCurrentPage('auth');
      return;
    }

    try {
      await axios.post('/api/cart', { productId, quantity: 1 });
      showMessage('success', 'Produit ajouté au panier');
      fetchCart();
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur ajout panier');
    }
  };

  // Mettre à jour quantité panier
  const updateCartQuantity = async (productId, quantity) => {
    try {
      await axios.put(`/api/cart/${productId}`, { quantity });
      fetchCart();
    } catch (error) {
      showMessage('error', 'Erreur mise à jour panier');
    }
  };

  // Créer une commande
  const createOrder = async (shippingAddress, paymentMethod) => {
    try {
      await axios.post('/api/orders', {

        shippingAddress,
        paymentMethod
      });
      showMessage('success', 'Commande créée avec succès !');
      fetchCart();
      setCurrentPage('orders');
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur création commande');
    }
  };

  // Charger les commandes
  const fetchOrders = async () => {
    if (!token) return;

    try {
      const response = await axios.get('/api/orders');
      setOrders(response.data);
    } catch (error) {
      showMessage('error', 'Erreur chargement commandes');
    }
  };

  // Effet pour charger données selon la page
  useEffect(() => {
    if (currentPage === 'home') {
      fetchProducts();
      fetchCategories();
    } else if (currentPage === 'cart') {
      fetchCart();
    } else if (currentPage === 'orders') {
      fetchOrders();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage, selectedCategory, searchTerm]);

  // Upload image produit
  const uploadProductImage = async (productId, file) => {
    const formData = new FormData();
    formData.append('image', file);

    try {
      const response = await axios.post(`/api/products/${productId}/image`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      showMessage('success', 'Image uploadée avec succès');
      fetchProducts();
      return response.data.url;
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur upload image');
      return null;
    }
  };

  // Créer un produit (Admin)
  const createProduct = async (productData) => {
    try {
      const response = await axios.post('/api/products', productData);
      showMessage('success', 'Produit créé avec succès');
      fetchProducts();
      return response.data.productId;
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur création produit');
      return null;
    }
  };

  // Mettre à jour un produit (Admin)
  const updateProduct = async (productId, productData) => {
    try {
      await axios.put(`/api/products/${productId}`, productData);
      showMessage('success', 'Produit mis à jour');
      fetchProducts();
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur mise à jour');
    }
  };

  // Supprimer un produit (Admin)
  const deleteProduct = async (productId) => {
    if (!window.confirm('Êtes-vous sûr de vouloir supprimer ce produit ?')) {
      return;
    }

    try {
      await axios.delete(`/api/products/${productId}`);
      showMessage('success', 'Produit supprimé');
      fetchProducts();
    } catch (error) {
      showMessage('error', error.response?.data?.error || 'Erreur suppression');
    }
  };

  // ===========================
  // RENDER COMPONENTS
  // ===========================

  const renderAuth = () => (
    <div className="auth-container">
      <h2>{isLogin ? 'Connexion' : 'Inscription'}</h2>
      <form onSubmit={handleAuth}>
        {!isLogin && (
          <>
            <input
              type="text"
              placeholder="Nom d'utilisateur"
              value={authForm.username}
              onChange={(e) => setAuthForm({ ...authForm, username: e.target.value })}
              required
            />
            <input
              type="text"
              placeholder="Prénom"
              value={authForm.firstName}
              onChange={(e) => setAuthForm({ ...authForm, firstName: e.target.value })}
              required
            />
            <input
              type="text"
              placeholder="Nom"
              value={authForm.lastName}
              onChange={(e) => setAuthForm({ ...authForm, lastName: e.target.value })}
              required
            />
          </>
        )}
        <input
          type="email"
          placeholder="Email"
          value={authForm.email}
          onChange={(e) => setAuthForm({ ...authForm, email: e.target.value })}
          required
        />
        <input
          type="password"
          placeholder="Mot de passe"
          value={authForm.password}
          onChange={(e) => setAuthForm({ ...authForm, password: e.target.value })}
          required
        />
        <button type="submit" className="btn-primary">
          {isLogin ? 'Se connecter' : 'S\'inscrire'}
        </button>
      </form>
      <button
        onClick={() => setIsLogin(!isLogin)}
        className="btn-link"
      >
        {isLogin ? 'Créer un compte' : 'Déjà un compte ? Se connecter'}
      </button>
    </div>
  );

  const renderProducts = () => (
    <div className="products-container">
      <div className="filters">
        <input
          type="text"
          placeholder="Rechercher un produit..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="search-input"
        />
        <select
          value={selectedCategory}
          onChange={(e) => setSelectedCategory(e.target.value)}
          className="category-select"
        >
          <option value="">Toutes les catégories</option>
          {categories.map(cat => (
            <option key={cat.id} value={cat.id}>{cat.name}</option>
          ))}
        </select>
        {user?.role === 'admin' && (
          <button onClick={() => setCurrentPage('admin')} className="btn-admin">
            📊 Dashboard Admin
          </button>
        )}
      </div>

      <div className="products-grid">
        {products.map(product => (
          <div key={product.id} className="product-card">
            <div className="product-image">
              {product.image_url ? (
                <img src={product.image_url} alt={product.name} />
              ) : (
                <div className="no-image">📦 Pas d'image</div>
              )}
            </div>
            <h3>{product.name}</h3>
            <p className="product-description">{product.description}</p>
            <div className="product-footer">
              <span className="price">{product.price} €</span>
              <span className="stock">Stock: {product.stock}</span>
            </div>
            <button
              onClick={() => addToCart(product.id)}
              disabled={product.stock === 0}
              className="btn-primary"
            >
              {product.stock > 0 ? 'Ajouter au panier' : 'Rupture de stock'}
            </button>
          </div>
        ))}
      </div>

      {products.length === 0 && (
        <div className="no-products">
          <p>Aucun produit trouvé</p>
        </div>
      )}
    </div>
  );

  const renderCart = () => (
    <div className="cart-container">
      <h2>Mon Panier</h2>
      {cart.items.length === 0 ? (
        <p>Votre panier est vide</p>
      ) : (
        <>
          <div className="cart-items">
            {cart.items.map(item => (
              <div key={item.product_id} className="cart-item">
                <img src={item.image_url || '/placeholder.png'} alt={item.name} />
                <div className="item-details">
                  <h3>{item.name}</h3>
                  <p>{item.price} €</p>
                </div>
                <div className="quantity-controls">
                  <button onClick={() => updateCartQuantity(item.product_id, item.quantity - 1)}>
                    -
                  </button>
                  <span>{item.quantity}</span>
                  <button onClick={() => updateCartQuantity(item.product_id, item.quantity + 1)}>
                    +
                  </button>
                </div>
                <div className="item-subtotal">
                  {item.subtotal} €
                </div>
              </div>
            ))}
          </div>
          <div className="cart-summary">
            <h3>Total: {parseFloat(cart.total || 0).toFixed(2)} €</h3>
            <button
              onClick={() => {
                const address = prompt('Adresse de livraison:');
                if (address) {
                  createOrder(address, 'card');
                }
              }}
              className="btn-primary"
            >
              Commander
            </button>
          </div>
        </>
      )}
    </div>
  );

  const renderOrders = () => (
    <div className="orders-container">
      <h2>Mes Commandes</h2>
      {orders.length === 0 ? (
        <p>Aucune commande</p>
      ) : (
        <div className="orders-list">
          {orders.map(order => (
            <div key={order.id} className="order-card">
              <div className="order-header">
                <span>Commande #{order.id}</span>
                <span className={`status ${order.status}`}>{order.status}</span>
              </div>
              <p>Total: {order.total_amount} €</p>
              <p>Articles: {order.items_count}</p>
              <p>Date: {new Date(order.created_at).toLocaleDateString()}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  // ===========================
  // ADMIN DASHBOARD
  // ===========================

  const [productForm, setProductForm] = useState({
    name: '',
    description: '',
    price: '',
    stock: '',
    categoryId: ''
  });
  const [editingProduct, setEditingProduct] = useState(null);
  const [uploadingImage, setUploadingImage] = useState(null);

  const renderAdminDashboard = () => (
    <div className="admin-dashboard">
      <div className="admin-header">
        <h2>📊 Dashboard Admin</h2>
        <button onClick={() => setCurrentPage('home')} className="btn-secondary">
          ← Retour aux produits
        </button>
      </div>

      {/* Formulaire Création/Édition Produit */}
      <div className="admin-section">
        <h3>{editingProduct ? '✏️ Modifier le produit' : '➕ Créer un nouveau produit'}</h3>
        <form
          className="product-form"
          onSubmit={async (e) => {
            e.preventDefault();

            if (editingProduct) {
              await updateProduct(editingProduct.id, productForm);
              setEditingProduct(null);
            } else {
              const productId = await createProduct(productForm);

              // Si une image est sélectionnée
              if (uploadingImage && productId) {
                await uploadProductImage(productId, uploadingImage);
                setUploadingImage(null);
              }
            }

            // Reset form
            setProductForm({
              name: '',
              description: '',
              price: '',
              stock: '',
              categoryId: ''
            });
          }}
        >
          <input
            type="text"
            placeholder="Nom du produit"
            value={productForm.name}
            onChange={(e) => setProductForm({ ...productForm, name: e.target.value })}
            required
          />

          <textarea
            placeholder="Description"
            value={productForm.description}
            onChange={(e) => setProductForm({ ...productForm, description: e.target.value })}
            rows="3"
          />

          <input
            type="number"
            step="0.01"
            placeholder="Prix (€)"
            value={productForm.price}
            onChange={(e) => setProductForm({ ...productForm, price: e.target.value })}
            required
          />

          <input
            type="number"
            placeholder="Stock"
            value={productForm.stock}
            onChange={(e) => setProductForm({ ...productForm, stock: e.target.value })}
            required
          />

          <select
            value={productForm.categoryId}
            onChange={(e) => setProductForm({ ...productForm, categoryId: e.target.value })}
            required
          >
            <option value="">Sélectionner une catégorie</option>
            {categories.map(cat => (
              <option key={cat.id} value={cat.id}>{cat.name}</option>
            ))}
          </select>

          <div className="file-input-wrapper">
            <label htmlFor="product-image" className="file-input-label">
              📷 {uploadingImage ? uploadingImage.name : 'Choisir une image'}
            </label>
            <input
              id="product-image"
              type="file"
              accept="image/*"
              onChange={(e) => setUploadingImage(e.target.files[0])}
              style={{ display: 'none' }}
            />
          </div>

          <div className="form-actions">
            <button type="submit" className="btn-primary">
              {editingProduct ? '💾 Mettre à jour' : '➕ Créer'}
            </button>
            {editingProduct && (
              <button
                type="button"
                onClick={() => {
                  setEditingProduct(null);
                  setProductForm({
                    name: '',
                    description: '',
                    price: '',
                    stock: '',
                    categoryId: ''
                  });
                }}
                className="btn-secondary"
              >
                ✖️ Annuler
              </button>
            )}
          </div>
        </form>
      </div>

      {/* Liste des Produits (Mode Admin) */}
      <div className="admin-section">
        <h3>📦 Tous les produits</h3>
        <div className="admin-products-list">
          {products.map(product => (
            <div key={product.id} className="admin-product-card">
              <div className="admin-product-image">
                {product.image_url ? (
                  <img src={product.image_url} alt={product.name} />
                ) : (
                  <div className="no-image">📦</div>
                )}
              </div>

              <div className="admin-product-info">
                <h4>{product.name}</h4>
                <p className="product-price">{product.price} €</p>
                <p className="product-stock">Stock: {product.stock}</p>
                <p className="product-category">{product.category_name}</p>
              </div>

              <div className="admin-product-actions">
                <button
                  onClick={() => {
                    setEditingProduct(product);
                    setProductForm({
                      name: product.name,
                      description: product.description || '',
                      price: product.price,
                      stock: product.stock,
                      categoryId: product.category_id
                    });
                    window.scrollTo({ top: 0, behavior: 'smooth' });
                  }}
                  className="btn-edit"
                >
                  ✏️ Modifier
                </button>

                <label className="btn-upload">
                  📷 Image
                  <input
                    type="file"
                    accept="image/*"
                    onChange={async (e) => {
                      const file = e.target.files[0];
                      if (file) {
                        await uploadProductImage(product.id, file);
                      }
                    }}
                    style={{ display: 'none' }}
                  />
                </label>

                <button
                  onClick={() => deleteProduct(product.id)}
                  className="btn-delete"
                >
                  🗑️ Supprimer
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  return (
    <div className="App">
      {/* Message de notification */}
      {message.text && (
        <div className={`message ${message.type}`}>
          {message.text}
        </div>
      )}

      {/* Navigation */}
      <nav className="navbar">
        <h1 onClick={() => setCurrentPage('home')}>🛒 E-Shop test de pipline</h1>
        <div className="nav-links">
          <button onClick={() => setCurrentPage('home')}>Produits</button>
          {user && (
            <>
              <button onClick={() => setCurrentPage('cart')}>
                Panier ({cart.items.length})
              </button>
              <button onClick={() => setCurrentPage('orders')}>
                Mes Commandes
              </button>
              <span className="user-info">👤 {user.username}</span>
              <button onClick={handleLogout}>Déconnexion</button>
            </>
          )}
          {!user && (
            <button onClick={() => setCurrentPage('auth')}>Connexion</button>
          )}
        </div>
      </nav>

      {/* Contenu principal */}
      <main className="main-content">
        {currentPage === 'home' && renderProducts()}
        {currentPage === 'auth' && renderAuth()}
        {currentPage === 'cart' && renderCart()}
        {currentPage === 'orders' && renderOrders()}
        {currentPage === 'admin' && user?.role === 'admin' && renderAdminDashboard()}
      </main>
    </div>
  );
}

export default App;
