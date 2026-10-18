const { test, describe, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');

const { recalculateSequentialTimes } = require('../src/features/itineraries/itineraries.service');
const { validateItineraryBeforeStart } = require('../src/features/trips/trips.service');
const itineraryRepo = require('../src/features/itineraries/itineraries.repository');

describe('Itinerary Time Auto-Recalculation on Reorder (Approach A)', () => {
  test('returns empty array when list is empty', () => {
    assert.deepEqual(recalculateSequentialTimes([]), []);
  });

  test('returns empty array when first item has no valid start_time', () => {
    const items = [
      { id: '1', start_time: null, end_time: '10:00' },
      { id: '2', start_time: '10:00', end_time: '11:00' },
    ];
    assert.deepEqual(recalculateSequentialTimes(items), []);
  });

  test('does not return updates when items already match sequential calculation', () => {
    const items = [
      { id: '1', start_time: '08:00', end_time: '09:00' },
      { id: '2', start_time: '09:00', end_time: '10:30' },
      { id: '3', start_time: '10:30', end_time: '11:30' },
    ];
    const updates = recalculateSequentialTimes(items);
    assert.deepEqual(updates, []);
  });

  test('recalculates sequential times preserving duration when items are swapped', () => {
    const items = [
      { id: 'B', start_time: '09:00', end_time: '10:30' },
      { id: 'A', start_time: '08:00', end_time: '09:00' },
    ];

    const updates = recalculateSequentialTimes(items);
    assert.equal(updates.length, 1);
    assert.deepEqual(updates[0], {
      id: 'A',
      startTime: '10:30',
      endTime: '11:30',
    });
  });

  test('recalculates sequential times when moving third item to first position', () => {
    const items = [
      { id: 'C', start_time: '10:30', end_time: '12:00' },
      { id: 'A', start_time: '08:00', end_time: '09:30' },
      { id: 'B', start_time: '09:30', end_time: '10:30' },
    ];

    const updates = recalculateSequentialTimes(items);
    assert.equal(updates.length, 2);
    assert.deepEqual(updates, [
      { id: 'A', startTime: '12:00', endTime: '13:30' },
      { id: 'B', startTime: '13:30', endTime: '14:30' },
    ]);
  });

  test('safely skips items with invalid duration or missing times without crashing', () => {
    const items = [
      { id: '1', start_time: '08:00', end_time: '09:00' },
      { id: '2', start_time: '10:00', end_time: '09:00' },
      { id: '3', start_time: null, end_time: null },
      { id: '4', start_time: '11:00', end_time: '12:00' },
    ];

    const updates = recalculateSequentialTimes(items);
    assert.equal(updates.length, 1);
    assert.deepEqual(updates[0], {
      id: '4',
      startTime: '09:00',
      endTime: '10:00',
    });
  });
});

describe('Trip Itinerary Validation Gate Before Start (Approach C)', () => {
  let origFindDays;
  let origFindItemsForDays;

  beforeEach(() => {
    origFindDays = itineraryRepo.findDays;
    origFindItemsForDays = itineraryRepo.findItemsForDays;
  });

  afterEach(() => {
    itineraryRepo.findDays = origFindDays;
    itineraryRepo.findItemsForDays = origFindItemsForDays;
  });

  test('rejects trip start with 422 when trip has no itinerary days', async () => {
    itineraryRepo.findDays = async () => [];
    await assert.rejects(
      () => validateItineraryBeforeStart({}, 'trip-1'),
      (err) => {
        assert.equal(err.status, 422);
        assert.match(err.message, /Chuyến đi chưa có lịch trình/);
        return true;
      }
    );
  });

  test('rejects trip start with 422 when days have no activities', async () => {
    itineraryRepo.findDays = async () => [{ id: 'day-1', day_number: 1 }];
    itineraryRepo.findItemsForDays = async () => [];
    await assert.rejects(
      () => validateItineraryBeforeStart({}, 'trip-1'),
      (err) => {
        assert.equal(err.status, 422);
        assert.match(err.message, /Lịch trình chưa có điểm đến nào/);
        return true;
      }
    );
  });

  test('allows starting when activities are strictly sequential and non-overlapping', async () => {
    itineraryRepo.findDays = async () => [{ id: 'day-1', day_number: 1 }];
    itineraryRepo.findItemsForDays = async () => [
      { itinerary_id: 'day-1', custom_name: 'Ăn sáng', start_time: '07:30', end_time: '08:30' },
      { itinerary_id: 'day-1', custom_name: 'Cà phê', start_time: '08:30', end_time: '09:30' },
      { itinerary_id: 'day-1', custom_name: 'Tham quan', start_time: '10:00', end_time: '12:00' },
    ];

    await assert.doesNotReject(() => validateItineraryBeforeStart({}, 'trip-1'));
  });

  test('rejects trip start with 422 when item has start_time >= end_time', async () => {
    itineraryRepo.findDays = async () => [{ id: 'day-1', day_number: 1 }];
    itineraryRepo.findItemsForDays = async () => [
      { itinerary_id: 'day-1', custom_name: 'Lặn biển', start_time: '14:00', end_time: '13:00' },
    ];

    await assert.rejects(
      () => validateItineraryBeforeStart({}, 'trip-1'),
      (err) => {
        assert.equal(err.status, 422);
        assert.match(err.message, /Lịch trình chưa hợp lệ/);
        assert.ok(Array.isArray(err.data));
        assert.match(err.data[0], /Ngày 1: "Lặn biển" có thời gian không hợp lệ/);
        return true;
      }
    );
  });

  test('rejects trip start with 422 when item is missing start or end time', async () => {
    itineraryRepo.findDays = async () => [{ id: 'day-1', day_number: 1 }];
    itineraryRepo.findItemsForDays = async () => [
      { itinerary_id: 'day-1', custom_name: 'Dạo phố', start_time: null, end_time: '15:00' },
    ];

    await assert.rejects(
      () => validateItineraryBeforeStart({}, 'trip-1'),
      (err) => {
        assert.equal(err.status, 422);
        assert.match(err.message, /Lịch trình chưa hợp lệ/);
        assert.match(err.data[0], /chưa có thời gian bắt đầu hoặc kết thúc/);
        return true;
      }
    );
  });

  test('rejects trip start with 422 when items overlap on the same day', async () => {
    itineraryRepo.findDays = async () => [
      { id: 'day-1', day_number: 1 },
      { id: 'day-2', day_number: 2 },
    ];
    itineraryRepo.findItemsForDays = async () => [
      { itinerary_id: 'day-1', custom_name: 'Ăn sáng', start_time: '08:00', end_time: '09:00' },
      { itinerary_id: 'day-2', custom_name: 'Check-in khách sạn', start_time: '11:00', end_time: '12:30' },
      { itinerary_id: 'day-2', custom_name: 'Ăn trưa', start_time: '12:00', end_time: '13:30' },
    ];

    await assert.rejects(
      () => validateItineraryBeforeStart({}, 'trip-1'),
      (err) => {
        assert.equal(err.status, 422);
        assert.match(err.message, /Lịch trình chưa hợp lệ/);
        assert.ok(Array.isArray(err.data));
        assert.equal(err.data.length, 1);
        assert.match(err.data[0], /Ngày 2: "Check-in khách sạn" \(kết thúc 12:30\) chồng lấn với "Ăn trưa" \(bắt đầu 12:00\)/);
        return true;
      }
    );
  });
});

