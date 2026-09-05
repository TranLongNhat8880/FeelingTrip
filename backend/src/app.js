const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const errorHandler = require('./shared/middlewares/error.middleware');
const { sendSuccess } = require('./shared/utils/response.util');

const app = express();

// ==========================================
// 1. GLOBAL MIDDLEWARES
// ==========================================
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ==========================================
// 2. HEALTH CHECK ROUTE
// ==========================================
app.get('/health', (req, res) => {
  return sendSuccess(res, { status: 'UP', timestamp: new Date().toISOString() }, 'Server is healthy');
});

// ==========================================
// 3. API FEATURE ROUTES
// ==========================================
const authRoutes = require('./features/auth/auth.routes');
const usersRoutes = require('./features/users/users.routes');
const tripsRoutes = require('./features/trips/trips.routes');
const itinerariesRoutes = require('./features/itineraries/itineraries.routes');
const companionsRoutes = require('./features/companions/companions.routes');
const expensesRoutes = require('./features/expenses/expenses.routes');
const reviewsRoutes = require('./features/reviews/reviews.routes');
const aiPlannerRoutes = require('./features/ai-planner/aiPlanner.routes');
const adminRoutes = require('./features/admin/admin.routes');
const placesRoutes = require('./features/places/places.routes');
const notificationsRoutes = require('./features/notifications/notifications.routes');

app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', usersRoutes);
app.use('/api/v1/trips', tripsRoutes);
app.use('/api/v1/itineraries', itinerariesRoutes);
app.use('/api/v1/places', placesRoutes);
app.use('/api/v1/companions', companionsRoutes);
app.use('/api/v1/expenses', expensesRoutes);
app.use('/api/v1/reviews', reviewsRoutes);
app.use('/api/v1/notifications', notificationsRoutes);
app.use('/api/v1/ai-planner', aiPlannerRoutes);
app.use('/api/v1/admin', adminRoutes);

// ==========================================
// 4. 404 & GLOBAL ERROR HANDLER
// ==========================================
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `API Route not found: ${req.method} ${req.originalUrl}`,
  });
});

app.use(errorHandler);

module.exports = app;
