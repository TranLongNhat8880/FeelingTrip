const multer = require('multer');
const apiError = require('../../shared/utils/apiError.util');

const receive = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 3, fields: 1, fieldSize: 128, parts: 5 },
}).fields([
  { name: 'cccdFrontImage', maxCount: 1 },
  { name: 'cccdBackImage', maxCount: 1 },
  { name: 'selfieImage', maxCount: 1 },
]);

module.exports = (req, res, next) => receive(req, res, error => {
  if (error instanceof multer.MulterError) {
    return next(apiError(error.code === 'LIMIT_FILE_SIZE' ? 413 : 400,
      error.code === 'LIMIT_FILE_SIZE' ? 'Mỗi ảnh tối đa 5 MB.' : 'Hồ sơ chỉ gồm số CCCD và ba ảnh xác minh.'));
  }
  next(error);
});
