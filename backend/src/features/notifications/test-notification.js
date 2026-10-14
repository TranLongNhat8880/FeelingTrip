const db = require('../../config/database');
const notificationsService = require('./notifications.service');

async function testCreateNotification() {
  try {
    const userId = "5d990a04-5fde-42a1-ad68-9302e23bf201";
    console.log(`Đang tạo thông báo thử nghiệm cho user ID: ${userId}`);

    // 2. Gọi service nội bộ để tạo thông báo
    const newNotification = await notificationsService.createNotification({
      recipientId: userId,
      title: 'Chuyến đi Đà Lạt sắp bắt đầu!',
      message: 'Lịch trình ngày mai đã sẵn sàng, hãy kiểm tra danh sách hành lý nhé.',
      type: 'TRIP_UPDATE',
      data: {
        tripId: 'sample-trip-id',
        screen: 'TripDetailScreen',
      },
    });

    console.log('Tạo thông báo thành công!');
    console.log('----------------------------------------------------');
    console.log(JSON.stringify(newNotification, null, 2));
  } catch (error) {
    console.error('Lỗi khi tạo thông báo:', error.message);
  } finally {
    await db.pool.end();
  }
}

testCreateNotification();
