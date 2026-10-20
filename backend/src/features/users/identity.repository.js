const { randomUUID, randomInt } = require("node:crypto");
const db = require("../../config/database");
const apiError = require("../../shared/utils/apiError.util");

async function createSession(userId) {
  return db.transaction(async (client) => {
    const { rows: users } = await client.query(
      "SELECT status, is_email_verified, is_verified, verification_status FROM users WHERE id=$1 FOR UPDATE",
      [userId],
    );
    const user = users[0];
    if (!user || user.status !== "ACTIVE" || !user.is_email_verified) {
      throw apiError(
        403,
        "Cần tài khoản hoạt động và email đã xác thực để xác minh danh tính.",
      );
    }
    if (user.is_verified || user.verification_status === "VERIFIED")
      throw apiError(409, "Tài khoản đã xác minh danh tính.");
    await client.query(
      `UPDATE ekyc_sessions SET status='ERROR', completed_at=NOW(), result='{"code":"PROCESSING_INTERRUPTED"}'::jsonb
      WHERE user_id=$1 AND status='PROCESSING' AND consumed_at<NOW()-INTERVAL '3 minutes'`,
      [userId],
    );
    const { rows: processing } = await client.query(
      "SELECT id FROM ekyc_sessions WHERE user_id=$1 AND status='PROCESSING' LIMIT 1",
      [userId],
    );
    if (processing[0])
      throw apiError(
        409,
        "Hồ sơ đang được xử lý. Vui lòng chờ kết quả rồi thử lại.",
      );
    const { rows: counts } = await client.query(
      `SELECT COUNT(*)::integer AS count FROM ekyc_sessions WHERE user_id=$1 AND created_at>NOW()-INTERVAL '15 minutes'`,
      [userId],
    );
    if (counts[0].count >= 5)
      throw apiError(
        429,
        "Đã thử xác minh nhiều lần. Vui lòng thử lại sau 15 phút.",
      );
    // Replacing a capture invalidates all older, unused challenges.
    await client.query(
      "UPDATE ekyc_sessions SET status='FAILED', completed_at=NOW() WHERE user_id=$1 AND status='CREATED'",
      [userId],
    );
    const actions = ["blink", "turnLeft", "turnRight"];
    for (let i = actions.length - 1; i > 0; i--) {
      const j = randomInt(i + 1);
      [actions[i], actions[j]] = [actions[j], actions[i]];
    }
    const { rows } = await client.query(
      "INSERT INTO ekyc_sessions(id,user_id,actions) VALUES($1,$2,$3) RETURNING id, actions, expires_at",
      [randomUUID(), userId, JSON.stringify(actions)],
    );
    return {
      sessionId: rows[0].id,
      actions: rows[0].actions,
      expiresAt: rows[0].expires_at,
    };
  });
}

async function consumeSession(userId, sessionId) {
  try {
    const { rows } = await db.query(
      `UPDATE ekyc_sessions SET status='PROCESSING', consumed_at=NOW()
       WHERE id=$1 AND user_id=$2 AND status='CREATED' AND expires_at>NOW() RETURNING id,actions`,
      [sessionId, userId],
    );
    if (!rows[0])
      throw apiError(
        409,
        "Phiên xác minh đã hết hạn hoặc đã sử dụng. Vui lòng quét lại khuôn mặt.",
      );
    return rows[0];
  } catch (error) {
    if (error.code === "23505")
      throw apiError(
        409,
        "Một hồ sơ khác đang được kiểm tra. Vui lòng chờ kết quả.",
      );
    throw error;
  }
}

async function finishSession(sessionId, status, result) {
  await db.query(
    `UPDATE ekyc_sessions SET status=$2,result=$3,completed_at=NOW() WHERE id=$1 AND status='PROCESSING'`,
    [sessionId, status, JSON.stringify(result)],
  );
}

// All verification writers acquire the same document lock before approving.
async function lockDocument(client, cccdNumber, userId) {
  await client.query(
    "SELECT pg_advisory_xact_lock(hashtextextended($1, 711))",
    [cccdNumber],
  );
  const { rows } = await client.query(
    `SELECT id FROM users WHERE cccd_number=$1 AND id<>$2 AND (is_verified=TRUE OR verification_status='VERIFIED') LIMIT 1`,
    [cccdNumber, userId],
  );
  if (rows[0])
    throw apiError(409, "Giấy tờ này đã được sử dụng cho một tài khoản khác.");
}

async function approve({ userId, sessionId, cccdNumber, images, result }) {
  return db.transaction(async (client) => {
    await lockDocument(client, cccdNumber, userId);
    // Same user -> session lock order as createSession, avoiding stale-job races.
    await client.query("SELECT id FROM users WHERE id=$1 FOR UPDATE", [userId]);
    const { rows: sessions } = await client.query(
      "SELECT id FROM ekyc_sessions WHERE id=$1 AND user_id=$2 AND status='PROCESSING' FOR UPDATE",
      [sessionId, userId],
    );
    if (!sessions[0]) throw apiError(409, "Phiên xác minh không còn hiệu lực.");
    const { rows } = await client.query(
      `UPDATE users SET cccd_number=$2,cccd_front_image=$3,cccd_back_image=$4,selfie_image=$5,
        verification_status='VERIFIED',is_verified=TRUE,verification_rejection_reason=NULL,updated_at=NOW()
       WHERE id=$1 AND status='ACTIVE' AND is_email_verified=TRUE AND is_verified=FALSE
         AND verification_status IN ('UNVERIFIED','REJECTED','PENDING')
       RETURNING verification_status,is_verified,updated_at`,
      [
        userId,
        cccdNumber,
        images.cccdFrontImage,
        images.cccdBackImage,
        images.selfieImage,
      ],
    );
    if (!rows[0])
      throw apiError(
        409,
        "Trạng thái tài khoản đã thay đổi. Vui lòng tải lại hồ sơ.",
      );
    await client.query(
      "UPDATE ekyc_sessions SET status='VERIFIED',result=$2,completed_at=NOW() WHERE id=$1",
      [sessionId, JSON.stringify(result)],
    );
    return rows[0];
  });
}

module.exports = {
  createSession,
  consumeSession,
  finishSession,
  lockDocument,
  approve,
};
