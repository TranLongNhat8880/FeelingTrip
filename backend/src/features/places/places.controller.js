const placesService = require('./places.service');
const {
    sendSuccess,
} = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: Places & Maps
// Tiếp nhận request, gọi service và trả response.
// ============================================================================

/**
 * [GET] /api/v1/places
 * Tìm kiếm địa điểm công khai.
 */
const searchPlaces = async (req, res, next) => {
    try {
        const result =
            await placesService.searchPlaces(req.query);

        return sendSuccess(
            res,
            result,
            'Lấy danh sách địa điểm thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [GET] /api/v1/places/manage
 * Admin xem toàn bộ kho địa điểm, kể cả địa điểm đã ẩn.
 */
const getManagePlaces = async (
    req,
    res,
    next
) => {
    try {
        const result =
            await placesService.getManagePlaces(
                req.query
            );

        return sendSuccess(
            res,
            result,
            'Lấy danh sách quản lý địa điểm thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [GET] /api/v1/places/:id
 * Xem chi tiết một địa điểm đang hoạt động.
 */
const getPlaceById = async (
    req,
    res,
    next
) => {
    try {
        const place =
            await placesService.getPlaceById(
                req.params.id
            );

        return sendSuccess(
            res,
            place,
            'Lấy thông tin địa điểm thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/places
 * Admin tạo địa điểm.
 *
 * Ảnh sử dụng multipart field "image".
 * Cloudinary middleware đặt URL ảnh vào req.file.path.
 */
const createPlace = async (
    req,
    res,
    next
) => {
    try {
        const place =
            await placesService.createPlace({
                placeData: req.body,
                imageUrl: req.file?.path,
            });

        return sendSuccess(
            res,
            place,
            'Thêm địa điểm thành công',
            HTTP_STATUS.CREATED
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [PUT] /api/v1/places/:id
 * Admin cập nhật thông tin và/hoặc ảnh địa điểm.
 */
const updatePlace = async (
    req,
    res,
    next
) => {
    try {
        const place =
            await placesService.updatePlace({
                placeId: req.params.id,
                placeData: req.body,
                imageUrl: req.file?.path,
            });

        return sendSuccess(
            res,
            place,
            'Cập nhật địa điểm thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [PATCH] /api/v1/places/:id/status
 * Admin ẩn hoặc khôi phục địa điểm.
 */
const updatePlaceStatus = async (
    req,
    res,
    next
) => {
    try {
        const place =
            await placesService.updatePlaceStatus({
                placeId: req.params.id,
                isActive: req.body.isActive,
            });

        return sendSuccess(
            res,
            place,
            req.body.isActive
                ? 'Khôi phục địa điểm thành công'
                : 'Ẩn địa điểm thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [GET] /api/v1/places/distance
 * Tính khoảng cách giữa hai tọa độ.
 */
const calculateDistance = async (
    req,
    res,
    next
) => {
    try {
        const result =
            placesService.calculateDistance(
                req.query
            );

        return sendSuccess(
            res,
            result,
            'Tính khoảng cách thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

/**
 * [POST] /api/v1/places/optimize-route
 * Gợi ý thứ tự ghé thăm các địa điểm.
 */
const optimizeRoute = async (
    req,
    res,
    next
) => {
    try {
        const result =
            await placesService.optimizeRoute(
                req.body
            );

        return sendSuccess(
            res,
            result,
            'Tối ưu lộ trình thành công',
            HTTP_STATUS.OK
        );
    } catch (error) {
        next(error);
    }
};

module.exports = {
    searchPlaces,
    getManagePlaces,
    getPlaceById,
    createPlace,
    updatePlace,
    updatePlaceStatus,
    calculateDistance,
    optimizeRoute,
};