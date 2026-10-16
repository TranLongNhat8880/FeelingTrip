const { test } = require('node:test');
const assert = require('node:assert/strict');
const dbPath = require.resolve('../src/config/database');
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: {} };
const repo = require('../src/features/admin/admin.repository');
const service = require('../src/features/admin/admin.service');

test('report API keeps target avatar separate from reporter and evidence images', async t => {
  t.mock.method(repo, 'getReports', async () => ({ rows: [{
    id: 'report', reporter_id: 'sender', reported_user_id: 'target',
    target_avatar_url: 'https://example.com/target.jpg',
    evidence_image_url: 'https://example.com/evidence.jpg', status: 'PENDING',
  }], total: 1 }));
  const response = await service.getReports({ page: 1, limit: 50 });
  assert.equal(response.items[0].reportedUserAvatarUrl, 'https://example.com/target.jpg');
  assert.equal(response.items[0].evidenceImageUrl, 'https://example.com/evidence.jpg');
});

test('moderation API returns actual trip cover or null without replacing it with evidence', async t => {
  t.mock.method(repo, 'getModerationPosts', async () => ({ rows: [
    { id: 'photo', trip_cover_image_url: 'https://example.com/trip.jpg' },
    { id: 'no-photo', trip_cover_image_url: null },
  ], total: 2 }));
  const response = await service.getModerationPosts({ page: 1, limit: 20 });
  assert.equal(response.items[0].trip_cover_image_url, 'https://example.com/trip.jpg');
  assert.equal(response.items[1].trip_cover_image_url, null);
});
