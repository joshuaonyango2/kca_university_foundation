require('dotenv').config();
const app = require('./src/app');
const pool = require('./src/config/database');

const PORT = process.env.PORT || 5000;

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ Database connection failed:', err);
    process.exit(1);
  }
  console.log('✅ Database connected at:', res.rows[0].now);
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`
  ╔═══════════════════════════════════════╗
  ║  🚀 KCA Foundation API Server         ║
  ║  📡 Running on port ${PORT}             ║
  ║  🌍 Environment: ${process.env.NODE_ENV || 'development'}        ║
  ║  📝 API Docs: http://localhost:${PORT}/   ║
  ╚═══════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
    pool.end(() => {
      console.log('Database pool closed');
      process.exit(0);
    });
  });
});