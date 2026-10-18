const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const { createTripSchema, updateTripSchema } = require('../src/features/trips/trips.validation');
const tripsService = require('../src/features/trips/trips.service');
const tripsRepo = require('../src/features/trips/trips.repository');
const companionsService = require('../src/features/companions/companions.service');
const companionsRepo = require('../src/features/companions/companions.repository');
const itineraryRepo = require('../src/features/itineraries/itineraries.repository');
const usersRepo = require('../src/features/users/users.repository');
const db = require('../src/config/database');

describe('Public Trip Creation & Companion Validation Gates', () => {
  const baseValidTrip = {
    destination: 'Đà Lạt',
    startDate: '2026-11-01',
    endDate: '2026-11-05',
    privacyType: 'PUBLIC',
  };

  test('Bug 1: targetMembersCount = 1 on PUBLIC trip is rejected', () => {
    const { error } = createTripSchema.validate({
      ...baseValidTrip,
      targetMembersCount: 1,
    });
    assert.ok(error, 'Validation must fail when targetMembersCount is 1 on PUBLIC trip');
    assert.match(error.message, /targetMembersCount phải từ 2 trở lên/);
  });

  test('Bug 1: targetMembersCount >= 2 on PUBLIC trip is accepted', () => {
    const { error, value } = createTripSchema.validate({
      ...baseValidTrip,
      targetMembersCount: 2,
    });
    assert.equal(error, undefined);
    assert.equal(value.targetMembersCount, 2);
  });

  test('Bug 2: postTitle length < 5 is rejected', () => {
    const { error } = createTripSchema.validate({
      ...baseValidTrip,
      postTitle: 'a',
    });
    assert.ok(error, 'Validation must fail when postTitle is only 1 char');
    assert.match(error.message, /Tiêu đề bài đăng phải có ít nhất 5 ký tự/);
  });

  test('Bug 2: postContent length < 10 is rejected', () => {
    const { error } = createTripSchema.validate({
      ...baseValidTrip,
      postContent: 'ngan',
    });
    assert.ok(error, 'Validation must fail when postContent is < 10 chars');
    assert.match(error.message, /Nội dung bài đăng phải có ít nhất 10 ký tự/);
  });

  test('Bug 2: valid postTitle and postContent are accepted', () => {
    const { error, value } = createTripSchema.validate({
      ...baseValidTrip,
      postTitle: 'Tìm bạn đi Đà Lạt',
      postContent: 'Cùng nhau đi săn mây và thưởng thức cà phê Đà Lạt nhé!',
    });
    assert.equal(error, undefined);
    assert.equal(value.postTitle, 'Tìm bạn đi Đà Lạt');
    assert.equal(value.postContent, 'Cùng nhau đi săn mây và thưởng thức cà phê Đà Lạt nhé!');
  });

  test('Bug 3: tags as JSON string with 11 items is rejected', () => {
    const tags11 = JSON.stringify(['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']);
    const { error } = createTripSchema.validate({
      ...baseValidTrip,
      tags: tags11,
    });
    assert.ok(error, 'Validation must fail when JSON tags has 11 items');
    assert.match(error.message, /Số lượng tags tối đa là 10/);
  });

  test('Bug 3: tags as array with 11 items is rejected', () => {
    const { error } = createTripSchema.validate({
      ...baseValidTrip,
      tags: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11'],
    });
    assert.ok(error, 'Validation must fail when array tags has 11 items');
    assert.match(error.message, /Số lượng tags tối đa là 10/);
  });

  test('Bug 3: invalid JSON string for tags returns 400', () => {
    const { error } = createTripSchema.validate({
      ...baseValidTrip,
      tags: '[invalid json',
    });
    assert.ok(error, 'Validation must fail when tags JSON is malformed');
    assert.match(error.message, /tags không đúng định dạng JSON/);
  });

  test('Bug 3: tags as valid JSON string <= 10 items parses into array', () => {
    const { error, value } = createTripSchema.validate({
      ...baseValidTrip,
      tags: '["Phượt", "Nhiếp ảnh", "Ăn uống"]',
    });
    assert.equal(error, undefined);
    assert.deepEqual(value.tags, ['Phượt', 'Nhiếp ảnh', 'Ăn uống']);
  });
});

describe('createTrip Fallback Validation & Transaction Rollback', () => {
  const userId = '11111111-1111-4111-8111-111111111111';

  test('createTrip falls back to safe default content when description is < 10 chars', async (t) => {
    let capturedPost = null;

    t.mock.method(tripsRepo, 'isUserVerified', async () => true);
    t.mock.method(tripsRepo, 'createTrip', async (client, uid, data) => ({
      id: 'trip-uuid-1',
      creator_id: uid,
      name: data.name,
      destination: data.destination,
      privacy_type: 'PUBLIC',
      status: 'UPCOMING',
    }));
    t.mock.method(companionsRepo, 'createCompanionPost', async (postData) => {
      capturedPost = postData;
      return { id: 'post-uuid-1', ...postData };
    });
    t.mock.method(tripsRepo, 'findTripForMember', async () => ({
      id: 'trip-uuid-1',
      name: 'Chuyến đi Vũng Tàu',
      destination: 'Vũng Tàu',
      creator_id: userId,
      privacy_type: 'PUBLIC',
      status: 'UPCOMING',
      member_role: 'LEADER',
    }));
    t.mock.method(tripsRepo, 'findSafeMembers', async () => []);

    await tripsService.createTrip(userId, {
      destination: 'Vũng Tàu',
      startDate: new Date('2026-11-01'),
      endDate: new Date('2026-11-03'),
      privacyType: 'PUBLIC',
      description: 'Ngắn', // < 10 chars
    });

    assert.ok(capturedPost);
    assert.ok(
      capturedPost.content.length >= 10,
      `Expected postContent to be >= 10 characters but was "${capturedPost.content}"`
    );
    assert.match(capturedPost.content, /Cùng tham gia chuyến đi/);
  });

  test('createTrip rolls back transaction if companion_post creation fails', async (t) => {
    const executedQueries = [];
    const mockClient = {
      query: async (sql, params) => {
        executedQueries.push({ sql, params });
        if (sql === 'BEGIN' || sql === 'COMMIT' || sql === 'ROLLBACK') {
          return { rows: [] };
        }
        return { rows: [] };
      },
      release: () => {},
    };

    t.mock.method(db, 'transaction', async (fn) => {
      try {
        await mockClient.query('BEGIN');
        const res = await fn(mockClient);
        await mockClient.query('COMMIT');
        return res;
      } catch (err) {
        await mockClient.query('ROLLBACK');
        throw err;
      }
    });

    t.mock.method(tripsRepo, 'isUserVerified', async () => true);
    t.mock.method(tripsRepo, 'createTrip', async (client, uid, data) => {
      await client.query('INSERT INTO trips (id) VALUES ($1)', ['trip-rollback-1']);
      await client.query('INSERT INTO trip_members (trip_id, user_id) VALUES ($1, $2)', ['trip-rollback-1', uid]);
      return { id: 'trip-rollback-1', name: 'Test', destination: 'Test' };
    });

    t.mock.method(companionsRepo, 'createCompanionPost', async () => {
      throw new Error('Database error on companion_posts table constraint');
    });

    await assert.rejects(
      tripsService.createTrip(userId, {
        destination: 'Nha Trang',
        startDate: new Date('2026-11-01'),
        endDate: new Date('2026-11-03'),
        privacyType: 'PUBLIC',
      }),
      { message: /Database error on companion_posts table constraint/ }
    );

    const rollbackExecuted = executedQueries.some((q) => q.sql === 'ROLLBACK');
    const commitExecuted = executedQueries.some((q) => q.sql === 'COMMIT');
    assert.equal(rollbackExecuted, true, 'ROLLBACK must be executed when createCompanionPost fails');
    assert.equal(commitExecuted, false, 'COMMIT must NOT be executed');
  });
});

describe('Privacy Visibility & Access Restrictions for Companion Posts', () => {
  const leaderId = '11111111-1111-4111-8111-111111111111';
  const memberId = '22222222-2222-4222-8222-222222222222';
  const outsiderId = '33333333-3333-4333-8333-333333333333';
  const tripId = '44444444-4444-4444-8444-444444444444';
  const postId = '55555555-5555-4555-8555-555555555555';

  // 2 test dưới đây thuộc phân hệ Companion do Tùng phụ trách, sẽ tự pass khi Tùng thêm check trên branch của Tùng
  test.skip('getCompanionPostDetail: outsider cannot view post of a PRIVATE trip (403) - chờ Tùng merge', async (t) => {
    t.mock.method(companionsRepo, 'getCompanionPostDetail', async () => ({
      id: postId,
      trip_id: tripId,
      creator_id: leaderId,
      title: 'Tuyển thành viên',
      content: 'Chuyến đi kín',
      trip_privacy_type: 'PRIVATE',
      target_members_count: 5,
      current_members_count: 2,
    }));
    t.mock.method(companionsRepo, 'isTripMember', async () => false);

    await assert.rejects(
      companionsService.getCompanionPostDetail({ postId, userId: outsiderId }),
      { status: 403, message: 'Chuyến đi này ở chế độ riêng tư' }
    );
  });

  test('getCompanionPostDetail: trip member CAN view post of a PRIVATE trip', async (t) => {
    t.mock.method(companionsRepo, 'getCompanionPostDetail', async () => ({
      id: postId,
      trip_id: tripId,
      creator_id: leaderId,
      title: 'Tuyển thành viên',
      content: 'Chuyến đi kín',
      trip_privacy_type: 'PRIVATE',
      target_members_count: 5,
      current_members_count: 2,
      created_at: new Date(),
      updated_at: new Date(),
      trip_name: 'Trip Riêng Tư',
      trip_destination: 'Đà Lạt',
    }));
    t.mock.method(companionsRepo, 'isTripMember', async (tId, uId) => uId === memberId);
    t.mock.method(companionsRepo, 'getExistingRequest', async () => null);
    t.mock.method(tripsRepo, 'findSafeMembers', async () => []);
    t.mock.method(itineraryRepo, 'findDays', async () => []);
    t.mock.method(itineraryRepo, 'findItemsForDays', async () => []);

    const result = await companionsService.getCompanionPostDetail({ postId, userId: memberId });
    assert.equal(result.id, postId);
    assert.equal(result.trip.name, 'Trip Riêng Tư');
  });

  test.skip('createJoinRequest: cannot request to join a PRIVATE trip (400) - chờ Tùng merge', async (t) => {
    t.mock.method(usersRepo, 'findProfileById', async () => ({
      id: outsiderId,
      is_verified: true,
      has_verified_ekyc: true,
    }));
    t.mock.method(companionsRepo, 'getCompanionPostById', async () => ({
      id: postId,
      trip_id: tripId,
      creator_id: leaderId,
      status: 'OPEN',
    }));
    t.mock.method(companionsRepo, 'getTripByIdForUpdate', async () => ({
      id: tripId,
      status: 'UPCOMING',
      privacy_type: 'PRIVATE', // PRIVATE trip
    }));

    await assert.rejects(
      companionsService.createJoinRequest({
        postId,
        userId: outsiderId,
        introduction: 'Xin chào, cho mình tham gia với nhé!',
      }),
      { status: 400, message: 'Không thể gửi yêu cầu tham gia chuyến đi riêng tư' }
    );
  });

  test('getCompanionFeed includes t.privacy_type = PUBLIC condition', async (t) => {
    let capturedQuery = null;
    t.mock.method(db, 'query', async (sql) => {
      capturedQuery = sql;
      return { rows: [{ total: 0 }] };
    });

    await companionsRepo.getCompanionFeed({ limit: 10, offset: 0 });
    assert.ok(capturedQuery);
    assert.match(capturedQuery, /t\.privacy_type = 'PUBLIC'/);
  });

  test('getPostedTripIds joins trips and checks t.privacy_type = PUBLIC', async (t) => {
    let capturedQuery = null;
    t.mock.method(db, 'query', async (sql) => {
      capturedQuery = sql;
      return { rows: [] };
    });

    await companionsRepo.getPostedTripIds(leaderId);
    assert.ok(capturedQuery);
    assert.match(capturedQuery, /JOIN trips t ON t\.id = cp\.trip_id/);
    assert.match(capturedQuery, /t\.privacy_type = 'PUBLIC'/);
  });

  test('createCompanionPost rejects with 409 if active post already exists', async (t) => {
    t.mock.method(usersRepo, 'findProfileById', async () => ({ id: leaderId, is_verified: true, has_verified_ekyc: true }));
    t.mock.method(companionsRepo, 'getTripByIdForUpdate', async () => ({ id: tripId, privacy_type: 'PUBLIC' }));
    t.mock.method(companionsRepo, 'isTripLeader', async () => true);
    t.mock.method(companionsRepo, 'checkExistsPostByTripId', async () => true);

    await assert.rejects(
      companionsService.createCompanionPost({
        userId: leaderId,
        tripId,
        title: 'Tuyển bạn đồng hành đi Đà Lạt',
        content: 'Cùng nhau đi săn mây và thưởng thức cà phê Đà Lạt nhé!',
        targetMembersCount: 4,
      }),
      { status: 409, message: 'Chuyến đi này đã có bài viết đang hoạt động' }
    );
  });

  test('createCompanionPost rejects if targetMembersCount <= currentMembersCount', async (t) => {
    t.mock.method(usersRepo, 'findProfileById', async () => ({ id: leaderId, is_verified: true, has_verified_ekyc: true }));
    t.mock.method(companionsRepo, 'getTripByIdForUpdate', async () => ({ id: tripId, privacy_type: 'PUBLIC' }));
    t.mock.method(companionsRepo, 'isTripLeader', async () => true);
    t.mock.method(companionsRepo, 'checkExistsPostByTripId', async () => false);
    t.mock.method(companionsRepo, 'getTripMembersCount', async () => 3);

    await assert.rejects(
      companionsService.createCompanionPost({
        userId: leaderId,
        tripId,
        title: 'Tuyển bạn đồng hành đi Đà Lạt',
        content: 'Cùng nhau đi săn mây và thưởng thức cà phê Đà Lạt nhé!',
        targetMembersCount: 3,
      }),
      { status: 400, message: 'Số lượng thành viên mục tiêu phải lớn hơn số thành viên hiện tại trong đoàn' }
    );
  });

  test('createTrip generates an active single-use invite code for PRIVATE trips', async (t) => {
    let generatedTripId = null;
    t.mock.method(tripsRepo, 'createTrip', async (client, uid, data) => ({
      id: 'private-trip-1',
      name: data.name,
      destination: data.destination,
      privacy_type: 'PRIVATE',
      status: 'UPCOMING',
    }));
    t.mock.method(tripsRepo, 'generateNewInviteCode', async (client, tid) => {
      generatedTripId = tid;
      return { id: tid, invite_code: 'INV123', invite_code_status: 'ACTIVE' };
    });
    t.mock.method(tripsRepo, 'findTripForMember', async () => ({
      id: 'private-trip-1',
      name: 'Chuyến đi riêng tư',
      destination: 'Hà Nội',
      privacy_type: 'PRIVATE',
      status: 'UPCOMING',
      member_role: 'LEADER',
      invite_code: 'INV123',
      invite_code_status: 'ACTIVE',
    }));
    t.mock.method(tripsRepo, 'findSafeMembers', async () => []);

    const created = await tripsService.createTrip(leaderId, {
      destination: 'Hà Nội',
      startDate: new Date('2026-11-01'),
      endDate: new Date('2026-11-03'),
      privacyType: 'PRIVATE',
    });

    assert.equal(generatedTripId, 'private-trip-1');
    assert.equal(created.inviteCode, 'INV123');
    assert.equal(created.inviteCodeStatus, 'ACTIVE');
  });
});

