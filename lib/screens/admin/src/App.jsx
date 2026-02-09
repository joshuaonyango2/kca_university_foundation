import React from 'react';
import { BrowserRouter, Routes, Route, Link } from 'react-router-dom';

// Temporary Dashboard Component
function Dashboard() {
  return (
    <div style={{ padding: '20px' }}>
      <h1>Dashboard</h1>
      <p>Welcome to KCA Foundation Admin</p>
      <nav>
        <Link to="/">Home</Link> | 
        <Link to="/campaigns">Campaigns</Link> | 
        <Link to="/donations">Donations</Link>
      </nav>
    </div>
  );
}

// Temporary Home Component
function Home() {
  return (
    <div style={{ padding: '20px', textAlign: 'center' }}>
      <h1>KCA Foundation Admin Panel</h1>
      <nav style={{ marginTop: '20px' }}>
        <Link to="/dashboard" style={{ margin: '0 10px' }}>Dashboard</Link>
        <Link to="/campaigns" style={{ margin: '0 10px' }}>Campaigns</Link>
        <Link to="/donations" style={{ margin: '0 10px' }}>Donations</Link>
      </nav>
    </div>
  );
}

// Placeholder components
function Campaigns() {
  return <div style={{ padding: '20px' }}><h2>Campaigns</h2></div>;
}

function Donations() {
  return <div style={{ padding: '20px' }}><h2>Donations</h2></div>;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/campaigns" element={<Campaigns />} />
        <Route path="/donations" element={<Donations />} />
        <Route path="*" element={<div>Page not found</div>} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;