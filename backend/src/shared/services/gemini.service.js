const env = require('../../config/env');

// ============================================================================
// SERVICE: Google Gemini AI Travel Planner
// Tích hợp Google Gemini REST API để sinh lịch trình du lịch dạng Structured JSON
// ============================================================================

/**
 * Sinh lịch trình du lịch thông minh bằng Google Gemini API
 */
const generateItineraryWithGemini = async ({
  destination,
  durationDays = 3,
  estimatedBudget = null,
  travelStyle = 'CHILL',
  preferences = [],
}) => {
  const apiKey = env.geminiApiKey;

  // Nếu có Gemini API Key hợp lệ -> Gọi trực tiếp Google Gemini API
  if (apiKey && apiKey.trim() !== '') {
    try {
      const result = await callGeminiApi({
        apiKey,
        destination,
        durationDays,
        estimatedBudget,
        travelStyle,
        preferences,
      });
      if (result) return result;
    } catch (apiError) {
      console.warn(`[Gemini API Warning] ${apiError.message}. Chuyển sang sử dụng Local Smart Generator.`);
    }
  }

  // Fallback thông minh cục bộ khi chưa điền API Key hoặc khi mất mạng / hết quota
  return generateLocalSmartItinerary({
    destination,
    durationDays,
    estimatedBudget,
    travelStyle,
    preferences,
  });
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
  const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`;

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
   'RESTAURANT', 'CAFE', 'ATTRACTION', 'HOTEL', 'ENTERTAINMENT', 'NATURE', 'CULTURE', 'OTHER'.
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
    headers: { 'Content-Type': 'application/json' },
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
  const budgetPerDay = estimatedBudget ? Math.round(Number(estimatedBudget) / durationDays) : 1000000;

  for (let i = 1; i <= durationDays; i++) {
    const dayItems = [
      {
        time: '08:00',
        activity: `Ăn sáng đặc sản địa phương tại ${destination}`,
        category: 'RESTAURANT',
        estimatedCost: Math.round(budgetPerDay * 0.08),
        note: 'Nên đi sớm trước 9h để tránh đông đúc',
      },
      {
        time: '09:30',
        activity: `Tham quan điểm check-in văn hóa / thắng cảnh nổi tiếng tại ${destination}`,
        category: 'ATTRACTION',
        estimatedCost: Math.round(budgetPerDay * 0.15),
        note: 'Chuẩn bị trang phục phù hợp để chụp ảnh',
      },
      {
        time: '12:00',
        activity: `Thưởng thức ẩm thực trưa món ngon địa phương`,
        category: 'RESTAURANT',
        estimatedCost: Math.round(budgetPerDay * 0.2),
        note: 'Trải nghiệm hương vị bản địa đặc sắc',
      },
      {
        time: '14:30',
        activity: `Thư giãn tại quán cà phê có view đẹp`,
        category: 'CAFE',
        estimatedCost: Math.round(budgetPerDay * 0.1),
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
        estimatedCost: Math.round(budgetPerDay * 0.3),
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
    estimatedBudget: estimatedBudget ? Number(estimatedBudget) : calculatedTotalBudget,
    travelStyle,
    summary: `Chuyến du lịch khám phá ${destination} trong ${durationDays} ngày theo phong cách ${travelStyle}. Lịch trình được tối ưu hóa đường đi và phân bổ thời gian hợp lý.`,
    days,
  };
};

module.exports = {
  generateItineraryWithGemini,
};
