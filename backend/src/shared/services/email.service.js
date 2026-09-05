const nodemailer = require('nodemailer');
const env = require('../../config/env');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: env.email.user,
    pass: env.email.pass,
  },
});

/**
 * Gửi email chứa mã OTP xác thực đăng ký tài khoản
 */
const sendOtpEmail = async (toEmail, otpCode) => {
  const mailOptions = {
    from: `"FeelingTrip Support" <${env.email.user}>`,
    to: toEmail,
    subject: `[FeelingTrip] Mã xác thực OTP của bạn là: ${otpCode}`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
        <h2 style="color: #2b6cb0; text-align: center;">Chào mừng bạn đến với FeelingTrip! 🌍</h2>
        <p>Xin chào,</p>
        <p>Bạn đang thực hiện thao tác đăng ký hoặc xác thực tài khoản trên ứng dụng <strong>FeelingTrip</strong>. Dưới đây là mã xác thực OTP của bạn:</p>
        <div style="text-align: center; margin: 30px 0;">
          <span style="display: inline-block; font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #ffffff; background-color: #3182ce; padding: 12px 28px; border-radius: 6px;">
            ${otpCode}
          </span>
        </div>
        <p style="color: #718096; font-size: 14px;">Mã OTP này có hiệu lực trong vòng <strong>5 phút</strong>. Tuyệt đối không chia sẻ mã này cho bất kỳ ai để bảo vệ an toàn tài khoản.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;" />
        <p style="font-size: 12px; color: #a0aec0; text-align: center;">Đây là email tự động từ hệ thống FeelingTrip. Vui lòng không trả lời email này.</p>
      </div>
    `,
  };

  return transporter.sendMail(mailOptions);
};

module.exports = {
  transporter,
  sendOtpEmail,
};
