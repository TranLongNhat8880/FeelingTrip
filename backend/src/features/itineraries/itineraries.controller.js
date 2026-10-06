const service = require('./itineraries.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');

const run = handler => async (req, res, next) => {
  try { return await handler(req, res); }
  catch (error) {
    if (error.status) return sendError(res, error.message, error.status);
    return next(error);
  }
};

// ============================================================================
// CONTROLLER: Itineraries
// Xử lý các logic về kế hoạch theo ngày, clone plan và đổi địa điểm (smart swap)
// ============================================================================

/**
 * [GET] /api/v1/itineraries/trips/:tripId
 * Lấy toàn bộ lịch trình của một chuyến đi
 */
const getItineraries = run(async (req, res) => sendSuccess(res,
  await service.getItineraries(req.params.tripId, req.user.id), 'Lấy lịch trình thành công'));

/**
 * [POST] /api/v1/itineraries/trips/:tripId/days
 * Thêm một ngày mới vào lịch trình
 */
const createDay = run(async (req, res) => sendSuccess(res,
  await service.createDay(req.params.tripId, req.user.id, req.body), 'Tạo ngày lịch trình thành công', 201));

/**
 * [GET] /api/v1/itineraries/days/:dayId
 * Lấy chi tiết lịch trình của một ngày
 */
const getDay = run(async (req, res) => sendSuccess(res,
  await service.getDay(req.params.dayId, req.user.id), 'Lấy ngày lịch trình thành công'));

/**
 * [PATCH] /api/v1/itineraries/days/:dayId
 * Cập nhật thông tin ngày lịch trình (tiêu đề, ghi chú)
 */
const updateDay = run(async (req, res) => sendSuccess(res,
  await service.updateDay(req.params.dayId, req.user.id, req.body), 'Cập nhật ngày thành công'));

/**
 * [GET] /api/v1/itineraries/items/:itemId
 * Lấy chi tiết một hoạt động/địa điểm trong lịch trình
 */
const getItem = run(async (req, res) => sendSuccess(res,
  await service.getItem(req.params.itemId, req.user.id), 'Lấy hoạt động thành công'));

/**
 * [POST] /api/v1/itineraries/days/:dayId/items
 * Thêm hoạt động/địa điểm mới vào ngày lịch trình
 */
const addItem = run(async (req, res) => sendSuccess(res,
  await service.addItem(req.params.dayId, req.user.id, req.body), 'Thêm hoạt động thành công', 201));

/**
 * [PATCH] /api/v1/itineraries/items/:itemId
 * Cập nhật thông tin một hoạt động (thời gian, ghi chú)
 */
const updateItem = run(async (req, res) => sendSuccess(res,
  await service.updateItem(req.params.itemId, req.user.id, req.body), 'Cập nhật hoạt động thành công'));

/**
 * [DELETE] /api/v1/itineraries/items/:itemId
 * Xóa một hoạt động khỏi ngày lịch trình
 */
const deleteItem = run(async (req, res) => sendSuccess(res,
  await service.deleteItem(req.params.itemId, req.user.id, req.body), 'Xóa hoạt động thành công'));

/**
 * [PATCH] /api/v1/itineraries/items/:itemId/completion
 * Đánh dấu hoàn thành hoặc chưa hoàn thành cho một hoạt động
 */
const setCompletion = run(async (req, res) => sendSuccess(res,
  await service.setCompletion(req.params.itemId, req.user.id, req.body), 'Cập nhật hoàn thành thành công'));

const reorderItems = run(async (req, res) => sendSuccess(res,
  await service.reorderItems(req.params.dayId, req.user.id, req.body),
  'Sắp xếp hoạt động thành công'));

/**
 * [GET] /api/v1/itineraries/items/:itemId/swap-candidates
 * Tìm kiếm các địa điểm thay thế tương đương (Smart Swap candidates)
 */
const getSwapCandidates = run(async (req, res) => sendSuccess(res,
  await service.getSwapCandidates(req.params.itemId, req.user.id, req.query), 'Lấy gợi ý thay thế thành công'));

/**
 * [POST] /api/v1/itineraries/items/:itemId/swap
 * Áp dụng đổi địa điểm hiện tại sang địa điểm mới (Smart Swap)
 */
const applySmartSwap = run(async (req, res) => sendSuccess(res,
  await service.applySmartSwap(req.params.itemId, req.user.id, req.body), 'Đổi địa điểm thành công'));

/**
 * [POST] /api/v1/itineraries/smart-swap/apply
 * (Legacy) Áp dụng thay thế điểm B bằng B+
 */
const legacyApplySmartSwap = run(async (req, res) => sendSuccess(res,
  await service.applySmartSwap(req.body.itemId, req.user.id, req.body), 'Đổi địa điểm thành công'));

/**
 * [GET] /api/v1/itineraries/public
 * Lấy danh sách các lịch trình công khai (Public Plans)
 */
const listPublic = run(async (req, res) => sendSuccess(res,
  await service.listPublic(req.query), 'Lấy lịch trình công khai thành công'));

/**
 * [GET] /api/v1/itineraries/public/:sourceTripId
 * Xem chi tiết một lịch trình công khai
 */
const getPublic = run(async (req, res) => sendSuccess(res,
  await service.getPublic(req.params.sourceTripId), 'Lấy lịch trình công khai thành công'));

/**
 * [POST] /api/v1/itineraries/public/:sourceTripId/clone
 * Sao chép (clone/fork) lịch trình công khai vào chuyến đi của mình
 */
const clonePlan = run(async (req, res) => sendSuccess(res,
  await service.clonePlan(req.params.sourceTripId, req.user.id, req.body),
  'Nhân bản lịch trình thành công', 201));

module.exports = {
  getItineraries, createDay, getDay, updateDay, getItem, addItem, updateItem,
  deleteItem, setCompletion, reorderItems, getSwapCandidates, applySmartSwap, legacyApplySmartSwap,
  listPublic, getPublic, clonePlan,
};
