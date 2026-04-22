const express = require('express');
const router = express.Router();
const {
  getDashboard,
  getPendingPosts,
  getAllPosts,
  approvePost,
  rejectPost,
  featurePost,
  getUsers,
  updateUserRole,
  toggleUserActive,
  createCategory,
  runIngestionNow,
  getIngestionRunStatus,
  backfillThumbnails,
} = require('../controllers/adminController');
const { protect, authorize } = require('../middleware/authMiddleware');

// All admin routes require admin role
router.use(protect, authorize('admin'));

router.get('/dashboard', getDashboard);

// Post management
router.get('/posts', getAllPosts);
router.get('/posts/pending', getPendingPosts);
router.put('/posts/:id/approve', approvePost);
router.put('/posts/:id/reject', rejectPost);
router.put('/posts/:id/feature', featurePost);

// User management
router.get('/users', getUsers);
router.put('/users/:id/role', updateUserRole);
router.put('/users/:id/toggle-active', toggleUserActive);

// Category management
router.post('/categories', createCategory);

// News ingestion
router.post('/ingestion/run', runIngestionNow);
router.get('/ingestion/status', getIngestionRunStatus);

// Media maintenance
router.post('/media/backfill-thumbnails', backfillThumbnails);

module.exports = router;