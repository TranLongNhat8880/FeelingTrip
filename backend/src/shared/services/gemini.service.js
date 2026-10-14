const env = require('../../config/env');
const apiError = require('../utils/apiError.util');
const { normalizePlan } = require('../utils/itinerary.util');

// ============================================================================
// SERVICE: Google Gemini AI Travel Planner
// Tích hợp Google Gemini REST API để sinh lịch trình du lịch dạng Structured JSON
// ============================================================================

/**
 * Sinh lịch trình du lịch thông minh bằng Google Gemini API
 */
const generateItineraryWithGemini = async (input) => {
  try {
    if (!env.geminiApiKey || env.geminiApiKey.startsWith('your_')) throw new Error('missing_key');
    const plan = normalizePlan(await callGeminiApi({ ...input, apiKey: env.geminiApiKey }));
    if (plan.days.length !== input.durationDays) throw new Error('wrong_duration');
    const total = plan.days.reduce((sum, day) => sum + day.items.reduce((s, item) => s + item.estimatedCost, 0), 0);
    if (input.estimatedBudget != null && total > input.estimatedBudget) throw new Error('over_budget');
    return { ...plan, destination: input.destination, durationDays: input.durationDays,
      estimatedBudget: input.estimatedBudget ?? plan.estimatedBudget ?? total, source: 'gemini' };
  } catch (error) {
    // Provider errors may contain credentials or prompt data; return a stable public error.
    if (!env.aiAllowFallback) throw apiError(503, 'Chưa tạo được lịch trình AI. Vui lòng thử lại sau.');
    return { ...normalizePlan(generateLocalSmartItinerary(input)), source: 'fallback',
      warning: 'Đây là lịch trình mẫu cục bộ, chưa được Gemini tạo hoặc kiểm chứng địa điểm.' };
  }
};

/**
 * Gọi Google Gemini REST API với Structured JSON Output
 */
const callGeminiApi = async ({
  apiKey,
  destination,
  durationDays,
  estimatedBudget,
  travelStyle,
  preferences,
}) => {
  const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(env.geminiModel)}:generateContent`;

  const prompt = `
Bạn là một chuyên gia lập kế hoạch du lịch địa phương hàng đầu tại Việt Nam.
Hãy lập một lịch trình du lịch chi tiết và tối ưu nhất cho chuyến đi:
- Điểm đến: ${destination}
- Thời gian: ${durationDays} ngày
- Phong cách du lịch: ${travelStyle}
- Ngân sách ước tính: ${estimatedBudget ? `${Number(estimatedBudget).toLocaleString('vi-VN')} VNĐ` : 'Hợp lý, tối ưu chi phí'}
- Sở thích/Yêu cầu thêm: ${preferences && preferences.length > 0 ? preferences.join(', ') : 'Trải nghiệm ẩm thực và cảnh đẹp đặc trưng'}

YÊU CẦU ĐẶC BIỆT:
1. Bạn CHỈ ĐƯỢC trả về DUY NHẤT một chuỗi JSON hợp lệ, KHÔNG kèm giải thích, KHÔNG dùng markdown hay định dạng nào khác ngoài JSON.
2. Các danh mục (category) của từng hoạt động PHẢI thuộc một trong các giá trị:
   'RESTAURANT', 'CAFE', 'ATTRACTION', 'HOTEL', 'ENTERTAINMENT', 'NATURE', 'CULTURE', 'SHOPPING', 'OTHER'.
3. Định dạng JSON bắt buộc phải tuân theo cấu trúc sau:
{
  "tripName": "Tên chuyến đi hấp dẫn (Ví dụ: Khám phá Đà Lạt 3N2Đ - Chill & Ẩm Thực)",
  "destination": "${destination}",
  "durationDays": ${durationDays},
  "estimatedBudget": ${estimatedBudget || 3000000},
  "travelStyle": "${travelStyle}",
  "summary": "Tóm tắt ngắn gọn 1-2 câu về chuyến đi và lời khuyên thời tiết/trang phục",
  "days": [
    {
      "dayNumber": 1,
      "title": "Tiêu đề ngày (Ví dụ: Check-in trung tâm & Thưởng thức ẩm thực phố núi)",
      "items": [
        {
          "time": "08:30",
          "activity": "Tên hoạt động/quán ăn/địa điểm cụ thể",
          "category": "RESTAURANT",
          "estimatedCost": 45000,
          "note": "Mẹo hữu ích hoặc món nên thử"
        }
      ]
    }
  ]
}
`;

  const requestBody = {
    contents: [
      {
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      responseMimeType: 'application/json',
      temperature: 0.7,
    },
  };

  const response = await fetch(apiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    signal: AbortSignal.timeout(env.geminiTimeoutMs),
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Gemini API HTTP ${response.status}: ${errText}`);
  }

  const data = await response.json();
  const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) throw new Error('Không nhận được nội dung từ Gemini API');

  return JSON.parse(rawText);
};

/**
 * Trình sinh lịch trình cục bộ (Local Smart Itinerary Generator)
 * Dùng khi chưa có API Key hoặc offline - Đảm bảo dữ liệu chi tiết, chuẩn thực tế
 */
const generateLocalSmartItinerary = ({
  destination,
  durationDays = 3,
  estimatedBudget,
  travelStyle = 'CHILL',
  preferences = [],
}) => {
  const days = [];
  const budgetPerDay = estimatedBudget != null ? Math.floor(Number(estimatedBudget) / durationDays) : 1000000;

  for (let i = 1; i <= durationDays; i++) {
    const dayItems = [
      {
        time: '08:00',
        activity: `Ăn sáng đặc sản địa phương tại ${destination}`,
        category: 'RESTAURANT',
        estimatedCost: Math.floor(budgetPerDay * 0.08),
        note: 'Nên đi sớm trước 9h để tránh đông đúc',
      },
      {
        time: '09:30',
        activity: `Tham quan điểm check-in văn hóa / thắng cảnh nổi tiếng tại ${destination}`,
        category: 'ATTRACTION',
        estimatedCost: Math.floor(budgetPerDay * 0.15),
        note: 'Chuẩn bị trang phục phù hợp để chụp ảnh',
      },
      {
        time: '12:00',
        activity: `Thưởng thức ẩm thực trưa món ngon địa phương`,
        category: 'RESTAURANT',
        estimatedCost: Math.floor(budgetPerDay * 0.2),
        note: 'Trải nghiệm hương vị bản địa đặc sắc',
      },
      {
        time: '14:30',
        activity: `Thư giãn tại quán cà phê có view đẹp`,
        category: 'CAFE',
        estimatedCost: Math.floor(budgetPerDay * 0.1),
        note: 'Không gian yên tĩnh, ngắm cảnh và nghỉ ngơi',
      },
      {
        time: '17:30',
        activity: `Ngắm hoàng hôn và dạo phố ngắm cảnh`,
        category: 'NATURE',
        estimatedCost: 0,
        note: 'Thời điểm lý tưởng để chụp ảnh ánh sáng vàng',
      },
      {
        time: '19:30',
        activity: `Bữa tối nướng / lẩu đặc sản cùng nhóm`,
        category: 'RESTAURANT',
        estimatedCost: Math.floor(budgetPerDay * 0.3),
        note: 'Không gian ấm cúng, thưởng thức ẩm thực đêm',
      },
    ];

    days.push({
      dayNumber: i,
      title: i === 1 ? `Khám phá trung tâm & Trải nghiệm ẩm thực ${destination}` : `Hành trình ngày ${i} - Cảnh đẹp & Văn hóa bản địa`,
      items: dayItems,
    });
  }

  const calculatedTotalBudget = days.reduce(
    (sum, d) => sum + d.items.reduce((dSum, item) => dSum + item.estimatedCost, 0),
    0
  );

  return {
    tripName: `Hành trình ${destination} ${durationDays}N${durationDays - 1}Đ - ${travelStyle}`,
    destination,
    durationDays: Number(durationDays),
    estimatedBudget: estimatedBudget != null ? Number(estimatedBudget) : calculatedTotalBudget,
    travelStyle,
    summary: `Chuyến du lịch khám phá ${destination} trong ${durationDays} ngày theo phong cách ${travelStyle}. Lịch trình mẫu; cần chọn địa điểm cụ thể và kiểm tra đường đi.`,
    days,
  };
};

module.exports = {
  generateItineraryWithGemini,
};
