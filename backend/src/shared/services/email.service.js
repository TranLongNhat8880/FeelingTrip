const nodemailer = require('nodemailer');
const env = require('../../config/env');

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true,
  family: 4, // Force IPv4 to prevent ETIMEDOUT on cloud containers like Railway
  connectionTimeout: 15000,
  greetingTimeout: 15000,
  socketTimeout: 20000,
  auth: {
    user: env.email.user,
    pass: env.email.pass,
  },
});

// URL logo chính thức của FeelingTrip đã được lưu trữ trên Cloudinary CDN
const LOGO_URL = 'https://res.cloudinary.com/t1scpc2y/image/upload/v1788600701/feelingtrip_brand/feelingtrip_logo.png';

/**
 * Gửi email chứa mã OTP xác thực đăng ký tài khoản
 * Thiết kế sạch, phẳng, hiện đại theo nhận diện thương hiệu FeelingTrip
 */
const sendOtpEmail = async (toEmail, otpCode, type = 'VERIFY_EMAIL') => {
  const purpose = type === 'FORGOT_PASSWORD' ? 'đặt lại mật khẩu' : 'xác thực tài khoản';
  const mailOptions = {
    from: `"FeelingTrip Support" <${env.email.user}>`,
    to: toEmail,
    subject: `[FeelingTrip] Mã ${purpose}: ${otpCode}`,
    html: `
      <!DOCTYPE html>
      <html lang="vi">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Mã xác thực FeelingTrip</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #f0fdf4; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; -webkit-font-smoothing: antialiased;">
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #f0fdf4; padding: 30px 10px;">
          <tr>
            <td align="center">
              
              <!-- MAIN CONTAINER -->
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 580px; background-color: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 10px 30px rgba(16, 185, 129, 0.1); border: 1px solid #dcfce7;">
                
                <!-- HEADER VỚI GRADIENT XANH LÁ + XANH TRỜI -->
                <tr>
                  <td align="center" style="background: linear-gradient(135deg, #22c55e 0%, #16a34a 50%, #0ea5e9 100%); padding: 35px 20px 25px 20px; text-align: center;">
                    
                    <!-- LOGO CÓ VIỀN TRẮNG -->
                    <div style="display: inline-block; background-color: #ffffff; padding: 6px; border-radius: 24px; box-shadow: 0 6px 16px rgba(0, 0, 0, 0.12);">
                      <img src="${LOGO_URL}" alt="FeelingTrip Logo" width="105" height="105" style="display: block; border-radius: 18px; object-fit: cover;" />
                    </div>

                    <h1 style="color: #ffffff; font-size: 24px; font-weight: 800; margin: 16px 0 4px 0; letter-spacing: -0.3px;">
                      FeelingTrip
                    </h1>
                    <p style="color: #dcfce7; font-size: 13px; margin: 0; font-weight: 500; letter-spacing: 0.5px; text-transform: uppercase;">
                      Kết nối hành trình • Chia sẻ trải nghiệm
                    </p>
                  </td>
                </tr>

                <!-- NỘI DUNG CHÍNH -->
                <tr>
                  <td style="padding: 35px 35px 25px 35px; text-align: left;">
                    
                    <h2 style="color: #166534; font-size: 18px; font-weight: 700; margin: 0 0 14px 0;">
                      Chào bạn đồng hành mới,
                    </h2>
                    
                    <p style="color: #4b5563; font-size: 15px; line-height: 1.7; margin: 0 0 20px 0;">
                      Cảm ơn bạn đã lựa chọn <strong>FeelingTrip</strong>. Để ${purpose}, vui lòng nhập mã OTP dưới đây:
                    </p>

                    <!-- KHỐI MÃ OTP NỔI BẬT -->
                    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin: 25px 0;">
                      <tr>
                        <td align="center">
                          <div style="background: #f0fdf4; border: 2px dashed #22c55e; border-radius: 16px; padding: 20px 24px; display: inline-block; min-width: 260px; text-align: center;">
                            <div style="color: #15803d; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 6px;">
                              MÃ XÁC THỰC CỦA BẠN
                            </div>
                            <div style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; color: #15803d; letter-spacing: 8px; margin: 0;">
                              ${otpCode}
                            </div>
                            <div style="color: #65a30d; font-size: 12px; font-weight: 500; margin-top: 6px;">
                              Hiệu lực trong vòng 5 phút
                            </div>
                          </div>
                        </td>
                      </tr>
                    </table>

                    <!-- CẢNH BÁO AN TOÀN -->
                    <div style="background-color: #fefce8; border-left: 4px solid #eab308; border-radius: 6px; padding: 12px 16px; margin: 20px 0 25px 0;">
                      <p style="color: #854d0e; font-size: 13px; line-height: 1.5; margin: 0;">
                        <strong>Lưu ý bảo mật:</strong> Tuyệt đối không chia sẻ mã này cho bất kỳ ai, kể cả nhân viên hỗ trợ của FeelingTrip.
                      </p>
                    </div>

                    <p style="color: #6b7280; font-size: 14px; line-height: 1.6; margin: 0;">
                      Nếu bạn không yêu cầu mã này, vui lòng bỏ qua email hoặc liên hệ với chúng tôi để được hỗ trợ.
                    </p>
                  </td>
                </tr>

                <!-- FOOTER THƯƠNG HIỆU -->
                <tr>
                  <td style="background-color: #f8fafc; padding: 22px 35px; border-top: 1px solid #f1f5f9; text-align: center;">
                    <p style="color: #16a34a; font-size: 13px; font-weight: 600; margin: 0 0 6px 0;">
                      FeelingTrip • Nền tảng Quản lý Hành trình & Chia sẻ Chi phí Du lịch
                    </p>
                    <p style="color: #94a3b8; font-size: 12px; margin: 0 0 8px 0;">
                      Hỗ trợ: <a href="mailto:${env.email.user}" style="color: #0ea5e9; text-decoration: none;">${env.email.user}</a>
                    </p>
                    <p style="color: #cbd5e1; font-size: 11px; margin: 0;">
                      © 2026 FeelingTrip Team. All rights reserved.
                    </p>
                  </td>
                </tr>

              </table>
              <!-- END MAIN CONTAINER -->

            </td>
          </tr>
        </table>
      </body>
      </html>
    `,
  };

  // Gửi qua HTTP API (Port 443) nếu có API key của Resend hoặc Brevo
  // Giải pháp vượt qua việc các nền tảng đám mây như Railway chặn cổng SMTP (465/587).
  if (process.env.RESEND_API_KEY) {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: process.env.RESEND_FROM || 'FeelingTrip <onboarding@resend.dev>',
        to: [toEmail],
        subject: mailOptions.subject,
        html: mailOptions.html,
      }),
    });
    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Resend API error (${res.status}): ${err}`);
    }
    return res.json();
  }

  if (process.env.BREVO_API_KEY) {
    const res = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': process.env.BREVO_API_KEY,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        sender: {
          name: 'FeelingTrip Support',
          email: process.env.BREVO_SENDER_EMAIL || env.email.user || 'feelingtrip.official@gmail.com',
        },
        to: [{ email: toEmail }],
        subject: mailOptions.subject,
        htmlContent: mailOptions.html,
      }),
    });
    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Brevo API error (${res.status}): ${err}`);
    }
    return res.json();
  }

  return transporter.sendMail(mailOptions);
};

module.exports = {
  transporter,
  sendOtpEmail,
  LOGO_URL,
};
