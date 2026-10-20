const createError = require("../../shared/utils/apiError.util");
const apiError = (status, message) =>
  Object.assign(createError(status, message), { expose: true });
const repository = require("./identity.repository");
const cloudinary = require("../../config/cloudinary");

function config() {
  const url = process.env.EKYC_WORKER_URL;
  const key = process.env.EKYC_WORKER_KEY;
  if (!url || !key || key.length < 32)
    throw apiError(503, "Dịch vụ xác minh tự động chưa được cấu hình.");
  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    throw apiError(503, "Cấu hình dịch vụ xác minh không hợp lệ.");
  }
  if (
    !["https:", "http:"].includes(parsed.protocol) ||
    parsed.username ||
    parsed.password
  )
    throw apiError(503, "Cấu hình dịch vụ xác minh không hợp lệ.");
  return { url: parsed.origin, key };
}

async function ready() {
  const { url, key } = config();
  try {
    const response = await fetch(`${url}/health`, {
      headers: { "X-Worker-Key": key },
      signal: AbortSignal.timeout(4000),
      redirect: "error",
    });
    const body = await response.json();
    if (!response.ok || body.ready !== true) throw new Error("Not ready");
  } catch (_) {
    throw apiError(
      503,
      "Bộ xử lý xác minh chưa sẵn sàng. Vui lòng thử lại sau.",
    );
  }
}

async function createSession(userId) {
  await ready();
  return repository.createSession(userId);
}

// Document images are authenticated Cloudinary assets, never public uploads.
function uploadPrivate(buffer) {
  return new Promise((resolve, reject) => {
    cloudinary.uploader
      .upload_stream(
        {
          folder: "feelingtrip/identity",
          type: "authenticated",
          timeout: 10000,
          resource_type: "image",
          format: "jpg",
          transformation: [{ width: 1600, height: 1600, crop: "limit" }],
        },
        (error, result) => (error ? reject(error) : resolve(result)),
      )
      .end(buffer);
  });
}

async function verify({ userId, sessionId, cccdNumber, qrData, files }) {
  const { url, key } = config();
  for (const field of [
    "cccdFrontImage",
    "cccdBackImage",
    "selfieImage",
    "livenessVideo",
  ]) {
    const file = files?.[field]?.[0];
    if (!file?.buffer?.length)
      throw apiError(400, `Thiếu dữ liệu xác minh: ${field}`);
    if (file.buffer.length > (field === "livenessVideo" ? 20 : 5) * 1024 * 1024)
      throw apiError(413, "Ảnh tối đa 5 MB, video tối đa 20 MB.");
  }
  const session = await repository.consumeSession(userId, sessionId);
  const uploaded = [];
  try {
    const data = new FormData();
    data.set("actions", JSON.stringify(session.actions));
    data.set("cccdNumber", cccdNumber);
    data.set("qrData", qrData);
    for (const field of [
      "cccdFrontImage",
      "cccdBackImage",
      "selfieImage",
      "livenessVideo",
    ]) {
      const file = files[field][0];
      data.set(
        field,
        new Blob([file.buffer]),
        field === "livenessVideo" ? "capture.mp4" : "capture.jpg",
      );
    }
    let response, result;
    try {
      response = await fetch(`${url}/verify`, {
        method: "POST",
        headers: { "X-Worker-Key": key },
        body: data,
        signal: AbortSignal.timeout(110000),
        redirect: "error",
      });
      result = await response.json();
    } catch (_) {
      throw apiError(
        503,
        "Chưa nhận được kết quả xác minh. Vui lòng quét lại khuôn mặt rồi thử lại.",
      );
    }
    if (!response.ok)
      throw apiError(
        503,
        "Bộ xử lý xác minh đang bận hoặc gặp lỗi. Vui lòng thử lại.",
      );
    const scores = result.faceScores;
    const padScores = result.padScores;
    // Strict schema and an independent server threshold; truthy strings never pass.
    const passed =
      result.verified === true &&
      result.documentMatched === true &&
      result.livenessPassed === true &&
      result.faceMatched === true &&
      result.padPassed === true &&
      result.cccdNumber === cccdNumber &&
      result.model === "SFace-2021dec" &&
      Array.isArray(padScores) &&
      padScores.length >= 2 &&
      padScores.every(
        (x) =>
          typeof x === "number" && Number.isFinite(x) && x >= 0.9 && x <= 1,
      ) &&
      Array.isArray(scores) &&
      scores.length >= 3 &&
      scores.every(
        (x) =>
          typeof x === "number" && Number.isFinite(x) && x >= 0.5 && x <= 1,
      );
    const audit = {
      verified: passed,
      model: result.model,
      code: result.code,
      faceScores: Array.isArray(scores)
        ? scores.filter(Number.isFinite).slice(0, 12)
        : [],
      padScores: Array.isArray(padScores)
        ? padScores.filter(Number.isFinite).slice(0, 12)
        : [],
    };
    if (!passed) {
      await repository.finishSession(sessionId, "FAILED", audit);
      const messages = {
        DOCUMENT_MISMATCH:
          "Thông tin trên ảnh CCCD chưa khớp với mã QR. Vui lòng chụp lại rõ toàn bộ thẻ.",
        FACE_MISMATCH:
          "Khuôn mặt chưa khớp với ảnh trên CCCD. Vui lòng chụp lại tại nơi đủ sáng.",
        LIVENESS_FAILED:
          "Video chưa đạt kiểm tra thao tác trực tiếp. Vui lòng quét lại khuôn mặt.",
        IMAGE_QUALITY:
          "Ảnh chưa đủ rõ hoặc không có đúng một khuôn mặt. Vui lòng chụp lại.",
      };
      throw apiError(
        422,
        messages[result.code] ||
          "Chưa đủ điều kiện xác minh tự động. Vui lòng chụp và quét lại.",
      );
    }
    const images = {};
    for (const field of ["cccdFrontImage", "cccdBackImage", "selfieImage"]) {
      const asset = await uploadPrivate(files[field][0].buffer);
      uploaded.push(asset);
      images[field] = asset.secure_url;
    }
    const saved = await repository.approve({
      userId,
      sessionId,
      cccdNumber,
      images,
      result: audit,
    });
    return {
      verificationStatus: saved.verification_status,
      isVerified: saved.is_verified,
      verificationRejectionReason: null,
      submittedAt: saved.updated_at,
    };
  } catch (error) {
    await Promise.allSettled(
      uploaded.map((asset) =>
        cloudinary.uploader.destroy(asset.public_id, {
          type: "authenticated",
          resource_type: "image",
        }),
      ),
    );
    if (error.statusCode !== 422)
      await repository
        .finishSession(sessionId, "ERROR", { code: "PROCESSING_ERROR" })
        .catch(() => {});
    if (error.statusCode) throw error;
    throw apiError(503, "Chưa lưu được kết quả xác minh. Vui lòng thử lại.");
  }
}

module.exports = { createSession, verify };
