const multer = require("multer");
const apiError = require("../../shared/utils/apiError.util");
// Memory only: videos are forwarded privately and never retained by the API.
const receive = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 20 * 1024 * 1024,
    files: 4,
    fields: 3,
    fieldSize: 2048,
    parts: 7,
  },
}).fields([
  { name: "cccdFrontImage", maxCount: 1 },
  { name: "cccdBackImage", maxCount: 1 },
  { name: "selfieImage", maxCount: 1 },
  { name: "livenessVideo", maxCount: 1 },
]);

module.exports = (req, res, next) =>
  receive(req, res, (error) => {
    if (error instanceof multer.MulterError) {
      return next(
        apiError(
          error.code === "LIMIT_FILE_SIZE" ? 413 : 400,
          error.code === "LIMIT_FILE_SIZE"
            ? "Ảnh tối đa 5 MB và video tối đa 20 MB."
            : "Dữ liệu hồ sơ xác minh không hợp lệ hoặc có trường không được hỗ trợ.",
        ),
      );
    }
    next(error);
  });
