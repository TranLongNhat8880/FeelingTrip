const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const {
  createItineraryItemSchema,
  updateItineraryItemSchema,
} = require('../src/features/itineraries/itineraries.validation');
const {
  createTripSchema,
  updateTripSchema,
} = require('../src/features/trips/trips.validation');

describe('Location Sources & Coordinates Validation', () => {
  const validDayId = '11111111-1111-4111-8111-111111111111';
  const validPlaceId = '22222222-2222-4222-8222-222222222222';

  test('infers locationSource CATALOG when placeId is present and locationSource is omitted', () => {
    const { error, value } = createItineraryItemSchema.validate({
      placeId: validPlaceId,
      customName: 'Hồ Xuân Hương',
      startTime: '08:00',
      endTime: '09:30',
    });
    assert.ifError(error);
    assert.equal(value.locationSource, 'CATALOG');
  });

  test('infers locationSource MANUAL when placeId is absent and locationSource is omitted', () => {
    const { error, value } = createItineraryItemSchema.validate({
      customName: 'Quán ăn ven đường',
      startTime: '10:00',
      endTime: '11:00',
    });
    assert.ifError(error);
    assert.equal(value.locationSource, 'MANUAL');
  });

  test('rejects GEOAPIFY without latitude and longitude', () => {
    const { error } = createItineraryItemSchema.validate({
      customName: 'Chợ Đà Lạt',
      locationSource: 'GEOAPIFY',
      externalProvider: 'GEOAPIFY',
      externalPlaceId: 'place_123',
      startTime: '08:00',
      endTime: '09:00',
    });
    assert.ok(error);
    assert.match(error.message, /Tọa độ/);
  });

  test('rejects GEOAPIFY without externalPlaceId', () => {
    const { error } = createItineraryItemSchema.validate({
      customName: 'Chợ Đà Lạt',
      locationSource: 'GEOAPIFY',
      externalProvider: 'GEOAPIFY',
      latitude: 11.9404,
      longitude: 108.4583,
      startTime: '08:00',
      endTime: '09:00',
    });
    assert.ok(error);
    assert.match(error.message, /externalPlaceId/);
  });

  test('accepts valid GEOAPIFY item', () => {
    const { error, value } = createItineraryItemSchema.validate({
      customName: 'Chợ Đà Lạt',
      locationSource: 'GEOAPIFY',
      externalProvider: 'GEOAPIFY',
      externalPlaceId: 'geoapify_place_xyz',
      latitude: 11.9404,
      longitude: 108.4583,
      startTime: '08:00',
      endTime: '09:00',
    });
    assert.ifError(error);
    assert.equal(value.locationSource, 'GEOAPIFY');
    assert.equal(value.latitude, 11.9404);
    assert.equal(value.longitude, 108.4583);
  });

  test('rejects unpaired coordinates (latitude without longitude)', () => {
    const { error } = createItineraryItemSchema.validate({
      customName: 'Điểm test',
      locationSource: 'MANUAL',
      latitude: 11.9404,
      startTime: '08:00',
      endTime: '09:00',
    });
    assert.ok(error);
    assert.match(error.message, /cặp/);
  });

  test('rejects out of bounds coordinates', () => {
    const { error } = createItineraryItemSchema.validate({
      customName: 'Điểm test',
      locationSource: 'MANUAL',
      latitude: 95.0,
      longitude: 108.0,
      startTime: '08:00',
      endTime: '09:00',
    });
    assert.ok(error);
  });

  test('validates trip destination coordinates paired range', () => {
    const { error: err1 } = createTripSchema.validate({
      destination: 'Đà Lạt',
      startDate: '2026-11-01',
      endDate: '2026-11-05',
      destinationLatitude: 11.9404,
    });
    assert.ok(err1);
    assert.match(err1.message, /cặp/);

    const { error: err2, value } = createTripSchema.validate({
      destination: 'Đà Lạt',
      startDate: '2026-11-01',
      endDate: '2026-11-05',
      destinationLatitude: 11.9404,
      destinationLongitude: 108.4583,
      destinationProvider: 'GEOAPIFY',
      destinationExternalId: 'ext_dalat_123',
    });
    assert.ifError(err2);
    assert.equal(value.destinationLatitude, 11.9404);
    assert.equal(value.destinationLongitude, 108.4583);
  });
});

describe('Itineraries Service Location Source Logic', () => {
  const repo = require('../src/features/itineraries/itineraries.repository');
  const service = require('../src/features/itineraries/itineraries.service');

  test('resolveItemInput snapshots coordinates and metadata from active CATALOG place', async (t) => {
    const fakePlace = {
      id: '22222222-2222-4222-8222-222222222222',
      name: 'Thung Lũng Tình Yêu',
      address: 'Mai Anh Đào, Phường 8, Đà Lạt',
      category: 'ATTRACTION',
      latitude: 11.9798,
      longitude: 108.4497,
      is_active: true,
    };
    t.mock.method(repo, 'findPlace', async () => fakePlace);

    const resolved = await service.resolveItemInput({}, {
      placeId: fakePlace.id,
      locationSource: 'CATALOG',
      startTime: '09:00',
      endTime: '11:00',
    });

    assert.equal(resolved.locationSource, 'CATALOG');
    assert.equal(resolved.customName, fakePlace.name);
    assert.equal(resolved.customAddress, fakePlace.address);
    assert.equal(resolved.category, fakePlace.category);
    assert.equal(resolved.latitude, 11.9798);
    assert.equal(resolved.longitude, 108.4497);
    assert.equal(resolved.externalProvider, null);
    assert.equal(resolved.externalPlaceId, null);
  });

  test('resolveItemInput preserves GEOAPIFY coordinates and metadata without querying catalog', async (t) => {
    let queriedPlace = false;
    t.mock.method(repo, 'findPlace', async () => {
      queriedPlace = true;
      return null;
    });

    const resolved = await service.resolveItemInput({}, {
      locationSource: 'GEOAPIFY',
      externalProvider: 'GEOAPIFY',
      externalPlaceId: 'geo_12345',
      customName: 'Quảng trường Lâm Viên',
      category: 'SIGHTSEEING',
      latitude: 11.9366,
      longitude: 108.4452,
      startTime: '14:00',
      endTime: '16:00',
    });

    assert.equal(queriedPlace, false);
    assert.equal(resolved.locationSource, 'GEOAPIFY');
    assert.equal(resolved.placeId, null);
    assert.equal(resolved.externalProvider, 'GEOAPIFY');
    assert.equal(resolved.externalPlaceId, 'geo_12345');
    assert.equal(resolved.latitude, 11.9366);
    assert.equal(resolved.longitude, 108.4452);
  });

  test('getSwapCandidates rejects non-CATALOG items with 422', async (t) => {
    t.mock.method(repo, 'findItem', async () => ({
      id: '33333333-3333-4333-8333-333333333333',
      trip_id: '44444444-4444-4444-8444-444444444444',
      itinerary_id: '55555555-5555-4555-8555-555555555555',
      location_source: 'GEOAPIFY',
      place_id: null,
      latitude: 11.9366,
      longitude: 108.4452,
    }));
    t.mock.method(repo, 'getMembership', async () => ({ role: 'LEADER', membership_status: 'ACTIVE' }));

    await assert.rejects(
      () => service.getSwapCandidates('33333333-3333-4333-8333-333333333333', 'user_1', { radiusKm: 5, limit: 5 }),
      (err) => {
        assert.equal(err.status, 422);
        assert.match(err.message, /Smart Swap/);
        return true;
      }
    );
  });
});
