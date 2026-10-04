
// ============================================================================
// SERIALIZER: Trips
// Định dạng dữ liệu trả về (Response) cho Client
// ============================================================================
const asNumber = value => value == null ? 0 : Number(value);
/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 */
const asIso = value => value instanceof Date ? value.toISOString() : value;

/**
 * @description Xử lý thao tác thành viên đối với chuyến đi.
 */
const member = row => ({
  userId: row.user_id,
  displayName: row.display_name || row.full_name,
  avatarUrl: row.avatar_url || null,
  role: row.role,
  membershipStatus: row.membership_status,
  joinedAt: asIso(row.joined_at),
  ...(row.left_at ? { leftAt: asIso(row.left_at) } : {}),
  ...(row.removed_at ? { removedAt: asIso(row.removed_at) } : {}),
});

/**
 * @description Định dạng dữ liệu đầu ra cho chuyến đi.
 */
const summary = row => ({
  id: row.id,
  name: row.name,
  destination: row.destination,
  startDate: row.start_date,
  endDate: row.end_date,
  durationDays: Number(row.duration_days),
  estimatedBudget: asNumber(row.estimated_budget),
  coverImageUrl: row.cover_image_url || null,
  privacyType: row.privacy_type,
  status: row.status,
  memberRole: row.member_role || row.role,
  membershipStatus: row.membership_status || 'ACTIVE',
  memberCount: asNumber(row.member_count),
  isClone: Boolean(row.is_clone),
  originalTripId: row.original_trip_id || null,
  cloneCount: asNumber(row.clone_count),
  createdAt: asIso(row.created_at),
  updatedAt: asIso(row.updated_at),
});

/**
 * @description Định dạng dữ liệu đầu ra cho chuyến đi.
 * @param {string} row
 * @param {string} members
 * @param {string} leader
 */
const detail = (row, members, leader = false) => ({
  ...summary(row),
  description: row.description || null,
  members: members.map(member),
  ...(leader ? {
    inviteCode: row.invite_code || null,
    inviteCodeStatus: row.invite_code_status,
    inviteCodeExpiresAt: asIso(row.invite_code_expires_at),
  } : {}),
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} row
 * @param {string} includeInvitee
 */
const invitation = (row, includeInvitee = true) => ({
  id: row.id,
  trip: { id: row.trip_id, name: row.trip_name, destination: row.trip_destination },
  inviter: {
    userId: row.inviter_id,
    displayName: row.inviter_name,
    avatarUrl: row.inviter_avatar_url || null,
  },
  ...(includeInvitee ? { invitee: {
    userId: row.invitee_id,
    displayName: row.invitee_name,
    avatarUrl: row.invitee_avatar_url || null,
  } } : {}),
  status: row.status,
  expiresAt: asIso(row.expires_at),
  createdAt: asIso(row.created_at),
  respondedAt: asIso(row.responded_at),
  revokedAt: asIso(row.revoked_at),
});

/**
 * @description Thực thi logic nghiệp vụ cho chuyến đi.
 * @param {string} page
 * @param {string} limit
 * @param {string} total
 */
const pagination = (page, limit, total) => ({
  page, limit, total, totalPages: Math.ceil(total / limit),
});

module.exports = { member, summary, detail, invitation, pagination };
