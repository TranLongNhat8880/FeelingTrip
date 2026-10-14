const express = require('express');

const placesController = require('./places.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const authorize = require('../../shared/middlewares/role.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const upload = require('../../shared/middlewares/upload.middleware');
const { ROLES } = require('../../shared/constants/roles');

const {
    searchPlacesQuerySchema,
    managePlacesQuerySchema,
    createPlaceSchema,
    updatePlaceSchema,
    updatePlaceStatusSchema,
    distanceQuerySchema,
    optimizeRouteSchema,
    placeIdParamSchema,
} = require('./places.validation');

const router = express.Router();
router.use('/geocode', require('./geocoding.routes'));

// ============================================================================
// PUBLIC: SEARCH, MAPS & ROUTE
// ============================================================================

/**
 * Tìm kiếm kho địa điểm đang hoạt động.
 *
 * Query:
 * - keyword
 * - destination
 * - category
 * - priceLevel
 * - sortBy
 * - page
 * - limit
 */
router.get(
    '/',
    validate({
        query: searchPlacesQuerySchema,
    }),
    placesController.searchPlaces
);

/**
 * Tính khoảng cách giữa hai tọa độ.
 *
 * Phải đặt trước /:id để Express không hiểu
 * "distance" là ID địa điểm.
 */
router.get(
    '/distance',
    validate({
        query: distanceQuerySchema,
    }),
    placesController.calculateDistance
);

/**
 * Gợi ý thứ tự ghé thăm nhiều địa điểm.
 */
router.post(
    '/optimize-route',
    validate({
        body: optimizeRouteSchema,
    }),
    placesController.optimizeRoute
);

// ============================================================================
// ADMIN: QUẢN LÝ KHO ĐỊA ĐIỂM
// ============================================================================

/**
 * Xem cả địa điểm đang hoạt động và đã bị ẩn.
 *
 * Query bổ sung:
 * - isActive=true
 * - isActive=false
 */
router.get(
    '/manage',
    authenticate,
    authorize(ROLES.ADMIN),
    validate({
        query: managePlacesQuerySchema,
    }),
    placesController.getManagePlaces
);

/**
 * Tạo địa điểm bằng multipart/form-data.
 *
 * Field ảnh:
 * - image: File, không bắt buộc
 *
 * Các field còn lại gửi dưới dạng Text.
 */
router.post(
    '/',
    authenticate,
    authorize(ROLES.ADMIN),
    upload.single('image'),
    validate({
        body: createPlaceSchema,
    }),
    placesController.createPlace
);

/**
 * Cập nhật thông tin và/hoặc ảnh địa điểm.
 */
router.put(
    '/:id',
    authenticate,
    authorize(ROLES.ADMIN),
    upload.single('image'),
    validate({
        params: placeIdParamSchema,
        body: updatePlaceSchema,
    }),
    placesController.updatePlace
);

/**
 * Ẩn hoặc khôi phục địa điểm.
 *
 * Body JSON:
 * {
 *   "isActive": false
 * }
 */
router.patch(
    '/:id/status',
    authenticate,
    authorize(ROLES.ADMIN),
    validate({
        params: placeIdParamSchema,
        body: updatePlaceStatusSchema,
    }),
    placesController.updatePlaceStatus
);

// ============================================================================
// PUBLIC: PLACE DETAIL
// Luôn đặt route động /:id sau các route tĩnh.
// ============================================================================

router.get(
    '/:id',
    validate({
        params: placeIdParamSchema,
    }),
    placesController.getPlaceById
);

module.exports = router;
