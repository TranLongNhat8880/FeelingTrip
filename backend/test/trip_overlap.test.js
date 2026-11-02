const { test } = require('node:test');
const assert = require('node:assert/strict');
const tripsRepo = require('../src/features/trips/trips.repository');
const tripsService = require('../src/features/trips/trips.service');
const itinerariesService = require('../src/features/itineraries/itineraries.service');
const itinerariesRepo = require('../src/features/itineraries/itineraries.repository');
const db = require('../src/config/database');

test('findConflictingTrip executes correct SQL query and returns conflict', async () => {
  let capturedSql = '';
  let capturedParams = [];
  const mockClient = {
    query: async (sql, params) => {
      capturedSql = sql;
      capturedParams = params;
      return {
        rows: [{
          id: 'trip-123',
          name: 'Chuyến đi Đà Lạt',
          start_date: '2026-11-02',
          end_date: '2026-11-04',
        }],
      };
    },
  };

  const result = await tripsRepo.findConflictingTrip(
    mockClient,
    'user-1',
    '2026-11-03',
    '2026-11-05',
    'trip-999'
  );

  assert.equal(result.id, 'trip-123');
  assert.equal(result.name, 'Chuyến đi Đà Lạt');
  assert.match(capturedSql, /t\.start_date\s*<=\s*\$3/);
  assert.match(capturedSql, /t\.end_date\s*>=\s*\$2/);
  assert.match(capturedSql, /tm\.membership_status\s*=\s*'ACTIVE'/);
  assert.deepEqual(capturedParams, ['user-1', '2026-11-03', '2026-11-05', 'trip-999']);
});

test('findConflictingTrip returns null when query returns empty rows', async () => {
  const mockClient = {
    query: async () => ({ rows: [] }),
  };

  const result = await tripsRepo.findConflictingTrip(
    mockClient,
    'user-1',
    '2026-11-10',
    '2026-11-12'
  );

  assert.equal(result, null);
});

test('createTrip throws 409 Conflict when trip overlaps with an existing trip', async () => {
  const origFindConflictingTrip = tripsRepo.findConflictingTrip;
  const origTransaction = db.transaction;

  try {
    const mockClient = {};
    db.transaction = async (fn) => fn(mockClient);
    tripsRepo.findConflictingTrip = async () => ({
      id: 'trip-old',
      name: 'Chuyến đi Vũng Tàu',
      start_date: '2026-11-02',
      end_date: '2026-11-04',
    });

    await assert.rejects(
      async () => {
        await tripsService.createTrip('user-1', {
          destination: 'Đà Lạt',
          startDate: '2026-11-03',
          endDate: '2026-11-05',
        });
      },
      (err) => {
        assert.equal(err.statusCode, 409);
        assert.match(err.message, /Chuyến đi Vũng Tàu/);
        assert.match(err.message, /02\/11\/2026/);
        assert.match(err.message, /04\/11\/2026/);
        return true;
      }
    );
  } finally {
    tripsRepo.findConflictingTrip = origFindConflictingTrip;
    db.transaction = origTransaction;
  }
});

test('clonePlan throws 409 Conflict when cloned plan date overlaps with existing trip', async () => {
  const origFindTrip = itinerariesRepo.findTrip;
  const origFindDays = itinerariesRepo.findDays;
  const origFindConflictingTrip = tripsRepo.findConflictingTrip;
  const origTransaction = db.transaction;

  try {
    const mockClient = {};
    db.transaction = async (fn) => fn(mockClient);
    itinerariesRepo.findTrip = async () => ({
      id: 'source-1',
      name: 'Khám phá Hà Giang',
      destination: 'Hà Giang',
      status: 'COMPLETED',
      privacy_type: 'PUBLIC',
      duration_days: 3,
    });
    itinerariesRepo.findDays = async () => [
      { id: 'day-1', day_number: 1, title: 'Ngày 1' },
      { id: 'day-2', day_number: 2, title: 'Ngày 2' },
      { id: 'day-3', day_number: 3, title: 'Ngày 3' },
    ];
    tripsRepo.findConflictingTrip = async () => ({
      id: 'trip-old',
      name: 'Chuyến đi Sapa',
      start_date: '2026-11-02',
      end_date: '2026-11-04',
    });

    await assert.rejects(
      async () => {
        await itinerariesService.clonePlan('source-1', 'user-1', {
          startDate: '2026-11-02',
        });
      },
      (err) => {
        assert.equal(err.statusCode, 409);
        assert.match(err.message, /Chuyến đi Sapa/);
        assert.match(err.message, /02\/11\/2026/);
        assert.match(err.message, /04\/11\/2026/);
        return true;
      }
    );
  } finally {
    itinerariesRepo.findTrip = origFindTrip;
    itinerariesRepo.findDays = origFindDays;
    tripsRepo.findConflictingTrip = origFindConflictingTrip;
    db.transaction = origTransaction;
  }
});
