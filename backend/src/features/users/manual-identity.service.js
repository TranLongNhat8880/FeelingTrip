const cloudinary = require('../../config/cloudinary');
const repository = require('./users.repository');
const usersService = require('./users.service');
const createError = require('../../shared/utils/apiError.util');
const apiError = (status, message) => Object.assign(createError(status, message), { expose: true });

const imageFields = ['cccdFrontImage', 'cccdBackImage', 'selfieImage'];
const isImage = bytes => Buffer.isBuffer(bytes) && (
  bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff])) ||
  bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ||
  (bytes.subarray(0, 4).toString() === 'RIFF' && bytes.subarray(8, 12).toString() === 'WEBP')
);

const uploadImage = buffer => new Promise((resolve, reject) => {
  cloudinary.uploader.upload_stream({
    folder: 'feelingtrip/identity', type: 'authenticated', resource_type: 'image',
    format: 'jpg', timeout: 15000,
    transformation: [{ width: 1600, height: 1600, crop: 'limit' }],
  }, (error, asset) => error ? reject(error) : resolve(asset)).end(buffer);
});

async function submit({ userId, cccdNumber, files }) {
  for (const field of imageFields) {
    const file = files?.[field]?.[0];
    if (!file?.buffer?.length) throw apiError(400, 'Cần đủ ảnh mặt trước, mặt sau CCCD và ảnh chân dung.');
    if (file.buffer.length > 5 * 1024 * 1024) throw apiError(413, 'Mỗi ảnh tối đa 5 MB.');
    if (!isImage(file.buffer)) throw apiError(400, 'Ảnh cần ở định dạng JPG, PNG hoặc WEBP hợp lệ.');
  }
  const profile = await repository.findProfileById(userId);
  if (!profile) throw apiError(404, 'Không tìm thấy hồ sơ người dùng.');
  if (profile.is_verified || profile.verification_status === 'VERIFIED') throw apiError(409, 'Tài khoản đã được xác minh.');
  if (profile.verification_status === 'PENDING') throw apiError(409, 'Hồ sơ đang chờ quản trị viên xét duyệt.');

  const uploaded = [];
  try {
    const images = {};
    for (const field of imageFields) {
      const asset = await uploadImage(files[field][0].buffer);
      uploaded.push(asset);
      images[field] = asset.secure_url;
    }
    return await usersService.submitEkyc({ userId, cccdNumber, ...images });
  } catch (error) {
    await Promise.allSettled(uploaded.map(asset => cloudinary.uploader.destroy(asset.public_id, {
      type: 'authenticated', resource_type: 'image',
    })));
    if (error.status) throw error;
    throw apiError(503, 'Chưa lưu được hồ sơ. Vui lòng thử lại sau.');
  }
}

// Only the authorized admin endpoint returns these short-lived download links.
function adminDocumentUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    const cloud = cloudinary.config().cloud_name;
    const prefix = `/${cloud}/image/authenticated/`;
    if (url.hostname !== 'res.cloudinary.com' || !url.pathname.startsWith(prefix)) return value;
    const path = url.pathname.slice(prefix.length).replace(/^v\d+\//, '');
    const match = path.match(/^(.+)\.(jpg|jpeg|png|webp)$/i);
    if (!match || !match[1].startsWith('feelingtrip/identity/')) return null;
    return cloudinary.utils.private_download_url(decodeURIComponent(match[1]), match[2], {
      type: 'authenticated', resource_type: 'image', attachment: false,
      expires_at: Math.floor(Date.now() / 1000) + 600,
    });
  } catch (_) { return null; }
}

module.exports = { submit, adminDocumentUrl };
