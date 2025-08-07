import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [healthStatus, setHealthStatus] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkHealth();
    const interval = setInterval(checkHealth, 30000); // Check every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const checkHealth = async () => {
    try {
      const services = [
        { name: 'API Gateway', url: '/api/health' },
        { name: 'User Service', url: '/api/users/health' },
        { name: 'Product Service', url: '/api/products/health' },
        { name: 'Order Service', url: '/api/orders/health' }
      ];

      const status = {};
      for (const service of services) {
        try {
          const response = await fetch(service.url);
          status[service.name] = response.ok ? 'Healthy' : 'Unhealthy';
        } catch (error) {
          status[service.name] = 'Unavailable';
        }
      }
      setHealthStatus(status);
      setLoading(false);
    } catch (error) {
      console.error('Error checking health:', error);
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="App">
        <header className="App-header">
          <h1>E-Commerce Platform</h1>
          <p>Loading...</p>
        </header>
      </div>
    );
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>🛒 E-Commerce Microservices Platform</h1>
        <p>Welcome to our DevOps demonstration platform!</p>
      </header>
      
      <main className="App-main">
        <section className="health-status">
          <h2>Service Health Status</h2>
          <div className="services-grid">
            {Object.entries(healthStatus).map(([service, status]) => (
              <div key={service} className={`service-card ${status.toLowerCase()}`}>
                <h3>{service}</h3>
                <span className={`status ${status.toLowerCase()}`}>
                  {status === 'Healthy' ? '✅' : status === 'Unhealthy' ? '⚠️' : '❌'} {status}
                </span>
              </div>
            ))}
          </div>
        </section>

        <section className="api-endpoints">
          <h2>Available API Endpoints</h2>
          <div className="endpoints-grid">
            <div className="endpoint-card">
              <h3>User Service</h3>
              <ul>
                <li><code>GET /api/users</code> - List users</li>
                <li><code>POST /api/auth/register</code> - Register user</li>
                <li><code>POST /api/auth/login</code> - Login user</li>
              </ul>
            </div>
            <div className="endpoint-card">
              <h3>Product Service</h3>
              <ul>
                <li><code>GET /api/products</code> - List products</li>
                <li><code>GET /api/products/:id</code> - Get product</li>
                <li><code>GET /api/categories</code> - List categories</li>
              </ul>
            </div>
            <div className="endpoint-card">
              <h3>Order Service</h3>
              <ul>
                <li><code>GET /api/orders</code> - List orders</li>
                <li><code>POST /api/orders</code> - Create order</li>
                <li><code>GET /api/cart</code> - Get cart</li>
              </ul>
            </div>
          </div>
        </section>

        <section className="devops-info">
          <h2>DevOps Features</h2>
          <div className="features-grid">
            <div className="feature-card">
              <h3>🐳 Docker</h3>
              <p>Containerized microservices with individual databases</p>
            </div>
            <div className="feature-card">
              <h3>🔗 API Gateway</h3>
              <p>Centralized routing and load balancing</p>
            </div>
            <div className="feature-card">
              <h3>📊 Monitoring</h3>
              <p>Health checks and service status monitoring</p>
            </div>
            <div className="feature-card">
              <h3>🔒 Security</h3>
              <p>JWT authentication and secure headers</p>
            </div>
          </div>
        </section>
      </main>

      <footer className="App-footer">
        <p>Built with React, Node.js, and Docker | DevOps Course Demo</p>
        <button onClick={checkHealth} className="refresh-btn">
          🔄 Refresh Health Status
        </button>
      </footer>
    </div>
  );
}

export default App;
