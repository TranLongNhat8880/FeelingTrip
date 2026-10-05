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
}) => {
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

  const { rows } = await db.query(query, params);
  return rows[0] || null;
};


const getCompanionPostById = async (postId) => {
  const query = `
    SELECT *
    FROM companion_posts
    WHERE id = $1
  `;
  const params = [postId];
  const { rows } = await db.query(query, params);
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

const deleteCompanionPost = async (postId) => {
  const query = `
    UPDATE companion_posts
    SET status = 'CLOSED', updated_at = NOW()
    WHERE id = $1
    RETURNING *
  `;
  const params = [postId];
  const { rows } = await db.query(query, params);
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

module.exports = {
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
    isTripLeader
};
