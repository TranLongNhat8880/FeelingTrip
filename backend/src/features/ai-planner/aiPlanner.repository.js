const db = require('../../config/database');

// ============================================================================
// REPOSITORY: AI Travel Planner
// Thao tác lưu lịch trình thông minh do AI tạo vào cơ sở dữ liệu Supabase
// ============================================================================

/**
 * Lưu toàn bộ chuyến đi, thành viên, các ngày và hoạt động AI gợi ý (DB Transaction)
 */
const saveAiItineraryToDb = async ({
  userId,
  tripName,
  destination,
  startDate,
  endDate,
  estimatedBudget = 0,
  days = [],
}) => {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Tạo bản ghi chuyến đi chính trong bảng 'trips'
    const tripQuery = `
      INSERT INTO trips (creator_id, name, destination, start_date, end_date, estimated_budget, privacy_type, status)
      VALUES ($1, $2, $3, $4, $5, $6, 'PRIVATE', 'UPCOMING')
      RETURNING *;
    `;
    const tripValues = [
      userId,
      tripName,
      destination,
      startDate,
      endDate,
      estimatedBudget || 0,
    ];
    const { rows: tripRows } = await client.query(tripQuery, tripValues);
    const createdTrip = tripRows[0];

    // 2. Thêm người tạo làm LEADER trong bảng 'trip_members'
    const memberQuery = `
      INSERT INTO trip_members (trip_id, user_id, role)
      VALUES ($1, $2, 'LEADER')
      RETURNING *;
    `;
    await client.query(memberQuery, [createdTrip.id, userId]);

    // 3. Lưu từng ngày lịch trình vào bảng 'itineraries' và các hoạt động vào 'itinerary_items'
    const savedDays = [];
    const baseDate = new Date(startDate);

    for (const day of days) {
      // Tính ngày cụ thể: baseDate + (dayNumber - 1)
      const currentDayDate = new Date(baseDate);
      currentDayDate.setDate(baseDate.getDate() + (day.dayNumber - 1));

      const itineraryQuery = `
        INSERT INTO itineraries (trip_id, day_number, title, trip_date)
        VALUES ($1, $2, $3, $4)
        RETURNING *;
      `;
      const { rows: itineraryRows } = await client.query(itineraryQuery, [
        createdTrip.id,
        day.dayNumber,
        day.title || `Ngày ${day.dayNumber}`,
        currentDayDate.toISOString().split('T')[0],
      ]);
      const createdItinerary = itineraryRows[0];

      // 4. Lưu từng hoạt động trong ngày
      const savedItems = [];
      const items = day.items || [];
      for (let idx = 0; idx < items.length; idx++) {
        const item = items[idx];
        const itemQuery = `
          INSERT INTO itinerary_items (itinerary_id, custom_name, start_time, order_index, note, estimated_cost)
          VALUES ($1, $2, $3, $4, $5, $6)
          RETURNING *;
        `;
        const { rows: itemRows } = await client.query(itemQuery, [
          createdItinerary.id,
          item.activity || item.customName || 'Hoạt động trải nghiệm',
          item.time ? `${item.time}:00`.substring(0, 8) : null,
          idx + 1,
          item.note || null,
          item.estimatedCost || 0,
        ]);
        savedItems.push(itemRows[0]);
      }

      savedDays.push({
        ...createdItinerary,
        items: savedItems,
      });
    }

    await client.query('COMMIT');

    return {
      trip: createdTrip,
      itineraries: savedDays,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  saveAiItineraryToDb,
};
