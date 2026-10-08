const db = require('../../config/database');

const createCompanionPost = async ({
  tripId,
  creatorId,
  title,
  content,
  targetMembersCount,
  currentMembersCount,
  minAge = null,
  maxAge = null,
  genderPreference = 'ANY',
  tags = [],
}, client = db) => {
  const query = `
    INSERT INTO companion_posts (
      trip_id,
      creator_id,
      title,
      content,
      target_members_count,
      current_members_count,
      min_age,
      max_age,
      gender_preference,
      tags
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    RETURNING *
  `;

  const params = [
    tripId,
    creatorId,
    title,
    content,
    targetMembersCount,
    currentMembersCount,
    minAge,
    maxAge,
    genderPreference,
    tags,
  ];

  const { rows } = await client.query(query, params);
  return rows[0];
};

const checkExistsPostByTripId = async (tripId, client = db) => {
    const query = `
    SELECT EXISTS (
      SELECT 1
      FROM companion_posts
      WHERE trip_id = $1 AND status IN ('OPEN', 'FULL')
    )
  `;
  const params = [tripId];
  const { rows } = await client.query(query, params);
  return rows[0].exists;
};

const updateCompanionPost = async ({
  postId,
  newCreatorId,
  title,
  content,
  targetMembersCount,
  currentMembersCount,
  minAge,
  maxAge,
  genderPreference,
  tags,
  status,
}, client = db) => {
  const values = [];
  const params = [postId];
  if (newCreatorId !== undefined) {
    params.push(newCreatorId);
    values.push(`creator_id = $${params.length}`);
  }
  if (title !== undefined) {
    params.push(title);
    values.push(`title = $${params.length}`);
  }
  if (content !== undefined) {
    params.push(content);
    values.push(`content = $${params.length}`);
  }
  if (targetMembersCount !== undefined) {
    params.push(targetMembersCount);
    values.push(`target_members_count = $${params.length}`);
  }
  if (currentMembersCount !== undefined) {
    params.push(currentMembersCount);
    values.push(`current_members_count = $${params.length}`);
  }
  if (minAge !== undefined) {
    params.push(minAge);
    values.push(`min_age = $${params.length}`);
  }
  if (maxAge !== undefined) {
    params.push(maxAge);
    values.push(`max_age = $${params.length}`);
  }
  if (genderPreference !== undefined) {
    params.push(genderPreference);
    values.push(`gender_preference = $${params.length}`);
  }
  if (tags !== undefined) {
    params.push(tags);
    values.push(`tags = $${params.length}`);
  }
  if (status !== undefined) {
    params.push(status);
    values.push(`status = $${params.length}`);
  }

  if (values.length === 0) {
    return null;
  }

  values.push('updated_at = NOW()');

  const query = `
    UPDATE companion_posts
    SET ${values.join(', ')}
    WHERE id = $1
    RETURNING *
  `;

  const { rows } = await client.query(query, params);
  return rows[0] || null;
};


const getCompanionPostById = async (postId, client = db) => {
  const query = `
    SELECT *
    FROM companion_posts
    WHERE id = $1
  `;
  const params = [postId];
  const { rows } = await client.query(query, params);
  return rows[0] || null;
}

const getCompanionFeed = async ({
  limit = 20,
  offset = 0,
  sortBy = 'newest',
  destination,
  genderPreference,
  minAge,
  maxAge,
  status = 'OPEN',
}) => {
  const conditions = ["cp.status <> 'CLOSED'", "t.status IN ('UPCOMING', 'ONGOING')"];
  const params = [];

  if (status) {
    params.push(status);
    conditions.push(`cp.status = $${params.length}`);
  }

  if (destination) {
    params.push(`%${destination}%`);
    conditions.push(`(t.destination ILIKE $${params.length} OR cp.title ILIKE $${params.length})`);
  }

  if (genderPreference) {
    params.push(genderPreference);
    conditions.push(`(cp.gender_preference = $${params.length} OR cp.gender_preference = 'ANY')`);
  }

  if (minAge) {
    params.push(minAge);
    conditions.push(`(cp.min_age IS NULL OR cp.min_age >= $${params.length})`);
  }

  if (maxAge) {
    params.push(maxAge);
    conditions.push(`(cp.max_age IS NULL OR cp.max_age <= $${params.length})`);
  }

  const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  let orderByClause = 'cp.created_at DESC, cp.id DESC';
  if (sortBy === 'oldest') {
    orderByClause = 'cp.created_at ASC, cp.id DESC';
  } else if (sortBy === 'rating') {
    orderByClause = 'creator_trust_score DESC NULLS LAST, creator_review_count DESC, cp.created_at DESC, cp.id DESC';
  } else if (sortBy === 'departure_date') {
    orderByClause = 't.start_date ASC, cp.created_at DESC, cp.id DESC';
  }

  const countQuery = `
    SELECT COUNT(DISTINCT cp.id)::int AS total
    FROM companion_posts cp
    JOIN trips t ON t.id = cp.trip_id
    ${whereClause}
  `;
  const { rows: countRows } = await db.query(countQuery, params);
  const total = countRows[0]?.total || 0;

  const dataParams = [...params];
  dataParams.push(limit);
  const limitPlaceholder = `$${dataParams.length}`;
  dataParams.push(offset);
  const offsetPlaceholder = `$${dataParams.length}`;

  const dataQuery = `
    SELECT
      cp.id,
      cp.trip_id,
      cp.creator_id,
      cp.title,
      cp.target_members_count,
      cp.current_members_count,
      cp.min_age,
      cp.max_age,
      cp.gender_preference,
      cp.tags,
      cp.status,
      cp.created_at,
      cp.updated_at,
      t.name AS trip_name,
      t.destination AS trip_destination,
      t.start_date AS trip_start_date,
      t.end_date AS trip_end_date,
      t.duration_days AS trip_duration_days,
      t.estimated_budget AS trip_estimated_budget,
      t.cover_image_url AS trip_cover_image_url,
      t.status AS trip_status,
      u.full_name AS creator_name,
      u.nickname AS creator_nickname,
      u.avatar_url AS creator_avatar_url,
      u.is_verified AS creator_is_verified,
      COALESCE(ROUND(AVG(tr.rating)::NUMERIC, 1), 0)::FLOAT AS creator_trust_score,
      COUNT(tr.id)::INT AS creator_review_count
    FROM companion_posts cp
    JOIN trips t ON t.id = cp.trip_id
    JOIN users u ON u.id = cp.creator_id
    LEFT JOIN trip_reviews tr ON tr.reviewee_id = cp.creator_id
    ${whereClause}
    GROUP BY cp.id, t.id, u.id
    ORDER BY ${orderByClause}
    LIMIT ${limitPlaceholder} OFFSET ${offsetPlaceholder}
  `;

  const { rows } = await db.query(dataQuery, dataParams);
  return { rows, total };
};

const deleteCompanionPost = async (postId, client = db) => {
  const query = `
    UPDATE companion_posts
    SET status = 'CLOSED', updated_at = NOW()
    WHERE id = $1
    RETURNING *
  `;
  const params = [postId];
  const { rows } = await client.query(query, params);
  return rows[0] || null;
};

const getTripById = async (tripId, client = db) => {
  const query = 'SELECT * FROM trips WHERE id = $1 LIMIT 1';
  const { rows } = await client.query(query, [tripId]);
  return rows[0] || null;
};

const getTripByIdForUpdate = async (tripId, client = db) => {
  const query = 'SELECT * FROM trips WHERE id = $1 FOR UPDATE';
  const { rows } = await client.query(query, [tripId]);
  return rows[0] || null;
};

const getTripMembersCount = async (tripId, client = db) => {
  const query = `
    SELECT COUNT(*)::int AS count
    FROM trip_members
    WHERE trip_id = $1 AND membership_status = 'ACTIVE'
  `;
  const { rows } = await client.query(query, [tripId]);
  return rows[0]?.count || 0;
};

const getCompanionPostDetail = async (postId) => {
  const query = `
    SELECT
      cp.id,
      cp.trip_id,
      cp.creator_id,
      cp.title,
      cp.content,
      cp.target_members_count,
      cp.current_members_count,
      cp.min_age,
      cp.max_age,
      cp.gender_preference,
      cp.tags,
      cp.status,
      cp.created_at,
      cp.updated_at,
      t.name AS trip_name,
      t.destination AS trip_destination,
      t.start_date AS trip_start_date,
      t.end_date AS trip_end_date,
      t.duration_days AS trip_duration_days,
      t.estimated_budget AS trip_estimated_budget,
      t.cover_image_url AS trip_cover_image_url,
      t.status AS trip_status,
      u.full_name AS creator_name,
      u.nickname AS creator_nickname,
      u.avatar_url AS creator_avatar_url,
      u.is_verified AS creator_is_verified,
      COALESCE(ROUND(AVG(tr.rating)::NUMERIC, 1), 0)::FLOAT AS creator_trust_score,
      COUNT(tr.id)::INT AS creator_review_count
    FROM companion_posts cp
    JOIN trips t ON t.id = cp.trip_id
    JOIN users u ON u.id = cp.creator_id
    LEFT JOIN trip_reviews tr ON tr.reviewee_id = cp.creator_id
    WHERE cp.id = $1 AND cp.status <> 'CLOSED'
    GROUP BY cp.id, t.id, u.id
  `;
  const params = [postId];
  const { rows } = await db.query(query, params);
  return rows[0] || null;
};

const isTripLeader = async (tripId, userId, client = db) => {
  const query = `
    SELECT 1 FROM trip_members
    WHERE trip_id = $1 AND user_id = $2 AND role = 'LEADER' AND membership_status = 'ACTIVE'
    LIMIT 1
  `;
  const { rows } = await client.query(query, [tripId, userId]);
  return rows.length > 0;
};

const isTripMember = async (tripId, userId, client = db) => {
  const query = `
    SELECT 1 FROM trip_members
    WHERE trip_id = $1 AND user_id = $2 AND membership_status = 'ACTIVE'
    LIMIT 1
  `;
  const { rows } = await client.query(query, [tripId, userId]);
  return rows.length > 0;
};

const getTripLeader = async (tripId, client = db) => {
  const query = `
    SELECT user_id FROM trip_members
    WHERE trip_id = $1 AND role = 'LEADER' AND membership_status = 'ACTIVE'
    LIMIT 1
  `;
  const { rows } = await client.query(query, [tripId]);
  return rows[0] || null;
};

const createJoinRequest = async ({ postId, userId, introduction }, client = db) => {
  const query = `
    INSERT INTO companion_requests (post_id, user_id, introduction, status)
    VALUES ($1, $2, $3, 'PENDING')
    RETURNING *
  `;
  const { rows } = await client.query(query, [postId, userId, introduction || null]);
  return rows[0];
};

const getExistingRequest = async (postId, userId, client = db) => {
  const query = `
    SELECT * FROM companion_requests
    WHERE post_id = $1 AND user_id = $2
    LIMIT 1
  `;
  const { rows } = await client.query(query, [postId, userId]);
  return rows[0] || null;
};

const getJoinRequestById = async (requestId, client = db, forUpdate = false) => {
  const query = `
    SELECT
      cr.id,
      cr.post_id,
      cr.user_id,
      cr.introduction,
      cr.status,
      cr.created_at,
      cp.trip_id,
      cp.creator_id AS post_creator_id,
      cp.target_members_count,
      cp.current_members_count,
      cp.status AS post_status,
      t.name AS trip_name,
      u.full_name AS requester_name,
      u.nickname AS requester_nickname,
      u.avatar_url AS requester_avatar_url,
      u.phone AS requester_phone,
      u.is_verified AS requester_is_verified
    FROM companion_requests cr
    JOIN companion_posts cp ON cp.id = cr.post_id
    JOIN trips t ON t.id = cp.trip_id
    JOIN users u ON u.id = cr.user_id
    WHERE cr.id = $1
    LIMIT 1
    ${forUpdate ? 'FOR UPDATE OF cr' : ''}
  `;
  const { rows } = await client.query(query, [requestId]);
  return rows[0] || null;
};

const deleteJoinRequest = async (requestId, client = db) => {
  const query = `
    DELETE FROM companion_requests
    WHERE id = $1 AND status = 'PENDING'
    RETURNING *
  `;
  const { rows } = await client.query(query, [requestId]);
  return rows[0] || null;
};

const updateJoinRequestStatus = async (requestId, status, client = db) => {
  const query = `
    UPDATE companion_requests
    SET status = $2
    WHERE id = $1 AND status = 'PENDING'
    RETURNING *
  `;
  const { rows } = await client.query(query, [requestId, status]);
  return rows[0] || null;
};

const addTripMember = async (tripId, userId, role = 'MEMBER', client = db) => {
  const query = `
    INSERT INTO trip_members (trip_id, user_id, role, membership_status)
    VALUES ($1, $2, $3, 'ACTIVE')
    ON CONFLICT (trip_id, user_id) DO UPDATE
    SET membership_status = 'ACTIVE', role = EXCLUDED.role, joined_at = NOW(), left_at = NULL, removed_at = NULL, removed_by = NULL
    WHERE trip_members.membership_status <> 'ACTIVE'
    RETURNING *
  `;
  const { rows } = await client.query(query, [tripId, userId, role]);
  return rows[0];
};

const getMyReceivedRequests = async ({ userId, limit = 20, offset = 0, status, postId }, client = db) => {
  const conditions = [
    `(tm.user_id = $1 AND tm.role = 'LEADER' AND tm.membership_status = 'ACTIVE')`
  ];
  const params = [userId];

  if (status) {
    params.push(status);
    conditions.push(`cr.status = $${params.length}`);
  }

  if (postId) {
    params.push(postId);
    conditions.push(`cr.post_id = $${params.length}`);
  }

  const whereClause = conditions.join(' AND ');

  const dataQuery = `
    SELECT
      cr.id,
      cr.post_id,
      cr.user_id AS requester_id,
      cr.introduction,
      cr.status,
      cr.created_at,
      cp.title AS post_title,
      cp.target_members_count,
      cp.current_members_count,
      cp.status AS post_status,
      t.id AS trip_id,
      t.name AS trip_name,
      t.destination AS trip_destination,
      t.start_date AS trip_start_date,
      t.end_date AS trip_end_date,
      u.full_name AS requester_name,
      u.nickname AS requester_nickname,
      u.avatar_url AS requester_avatar_url,
      u.phone AS requester_phone,
      u.is_verified AS requester_is_verified,
      COALESCE(ROUND(AVG(tr.rating)::NUMERIC, 1), 0)::FLOAT AS requester_trust_score,
      COUNT(tr.id)::INT AS requester_review_count
    FROM companion_requests cr
    JOIN companion_posts cp ON cp.id = cr.post_id
    JOIN trips t ON t.id = cp.trip_id
    JOIN trip_members tm ON tm.trip_id = t.id
    JOIN users u ON u.id = cr.user_id
    LEFT JOIN trip_reviews tr ON tr.reviewee_id = cr.user_id
    WHERE ${whereClause}
    GROUP BY cr.id, cp.id, t.id, u.id
    ORDER BY cr.created_at DESC
    LIMIT $${params.length + 1} OFFSET $${params.length + 2}
  `;

  const countQuery = `
    SELECT COUNT(DISTINCT cr.id)::int AS total
    FROM companion_requests cr
    JOIN companion_posts cp ON cp.id = cr.post_id
    JOIN trips t ON t.id = cp.trip_id
    JOIN trip_members tm ON tm.trip_id = t.id
    WHERE ${whereClause}
  `;

  const [dataRes, countRes] = await Promise.all([
    client.query(dataQuery, [...params, limit, offset]),
    client.query(countQuery, params)
  ]);

  return {
    rows: dataRes.rows,
    total: countRes.rows[0]?.total || 0,
  };
};

const getPostedTripIds = async (userId) => {
  const { rows } = await db.query(`
    SELECT DISTINCT cp.trip_id
    FROM companion_posts cp
    JOIN trip_members tm ON tm.trip_id = cp.trip_id
    WHERE tm.user_id = $1 AND tm.role = 'LEADER'
      AND tm.membership_status = 'ACTIVE' AND cp.status IN ('OPEN', 'FULL')
  `, [userId]);
  return rows.map(row => row.trip_id);
};

module.exports = {
    getPostedTripIds,
    createCompanionPost,
    checkExistsPostByTripId,
    updateCompanionPost,
    getCompanionPostById,
    getCompanionFeed,
    getCompanionPostDetail,
    deleteCompanionPost,
    getTripById,
    getTripByIdForUpdate,
    getTripMembersCount,
    isTripLeader,
    isTripMember,
    getTripLeader,
    createJoinRequest,
    getExistingRequest,
    getJoinRequestById,
    deleteJoinRequest,
    updateJoinRequestStatus,
    addTripMember,
    getMyReceivedRequests
};
