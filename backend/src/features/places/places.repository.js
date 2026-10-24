const db = require('../../config/database');

// ============================================================================
// REPOSITORY: Places & Maps
// Chỉ thực hiện truy vấn bảng places; nghiệp vụ nằm ở service.
// ============================================================================

const PLACE_COLUMNS = `
  id,
  name,
  destination,
  address,
  category,
  latitude,
  longitude,
  image_url,
  price_level,
  avg_duration_minutes,
  rating,
  is_active,
  created_at
`;

/**
 * Tạo điều kiện lọc dùng chung cho truy vấn danh sách và đếm kết quả.
 *
 * Truy vấn công khai luôn lọc is_active = TRUE.
 * Chỉ API quản lý mới được truyền includeInactive = true.
 */
const buildPlaceFilters = (filters, includeInactive) => {
    const {
        keyword,
        destination,
        category,
        priceLevel,
        isActive,
    } = filters;

    const conditions = [];
    const values = [];

    if (!includeInactive) {
        conditions.push('is_active = TRUE');
    } else if (isActive !== undefined) {
        values.push(isActive);
        conditions.push(`is_active = $${values.length}`);
    }

    if (keyword) {
        values.push(`%${keyword}%`);
        const keywordIndex = values.length;

        conditions.push(`
      (
        name ILIKE $${keywordIndex}
        OR destination ILIKE $${keywordIndex}
        OR address ILIKE $${keywordIndex}
      )
    `);
    }

    if (destination) {
        values.push(`%${destination}%`);
        conditions.push(`destination ILIKE $${values.length}`);
    }

    if (category) {
        values.push(category);
        conditions.push(`category = $${values.length}`);
    }

    if (priceLevel !== undefined) {
        values.push(priceLevel);
        conditions.push(`price_level = $${values.length}`);
    }

    return {
        whereClause:
            conditions.length > 0
                ? `WHERE ${conditions.join(' AND ')}`
                : '',
        values,
    };
};

/**
 * Tìm kiếm và phân trang địa điểm.
 *
 * includeInactive = false:
 * - Dùng cho API công khai.
 * - Chỉ trả địa điểm đang hoạt động.
 *
 * includeInactive = true:
 * - Dùng cho API quản lý.
 * - Có thể xem và lọc địa điểm đã ẩn.
 */
const findPlaces = async (
    filters,
    { includeInactive = false } = {}
) => {
    const {
        sortBy = 'newest',
        page = 1,
        limit = 20,
    } = filters;

    const { whereClause, values } = buildPlaceFilters(
        filters,
        includeInactive
    );

    const sortMap = {
        newest: 'created_at DESC, id DESC',
        nameAsc: 'name ASC, id ASC',
        ratingDesc: 'rating DESC, name ASC, id ASC',
    };

    const orderClause = sortMap[sortBy] || sortMap.newest;
    const offset = (page - 1) * limit;

    const countQuery = `
    SELECT COUNT(*)::INTEGER AS total
    FROM places
    ${whereClause};
  `;

    const dataValues = [...values, limit, offset];
    const limitIndex = dataValues.length - 1;
    const offsetIndex = dataValues.length;

    const dataQuery = `
    SELECT ${PLACE_COLUMNS}
    FROM places
    ${whereClause}
    ORDER BY ${orderClause}
    LIMIT $${limitIndex}
    OFFSET $${offsetIndex};
  `;

    const [countResult, dataResult] = await Promise.all([
        db.query(countQuery, values),
        db.query(dataQuery, dataValues),
    ]);

    return {
        places: dataResult.rows,
        total: countResult.rows[0]?.total || 0,
    };
};

/**
 * Lấy chi tiết một địa điểm.
 *
 * Mặc định chỉ lấy địa điểm đang hoạt động.
 * Admin có thể dùng includeInactive để xem địa điểm đã ẩn.
 */
const findPlaceById = async (
    placeId,
    { includeInactive = false } = {}
) => {
    const activeCondition = includeInactive
        ? ''
        : 'AND is_active = TRUE';

    const query = `
    SELECT ${PLACE_COLUMNS}
    FROM places
    WHERE id = $1
      ${activeCondition}
    LIMIT 1;
  `;

    const { rows } = await db.query(query, [placeId]);
    return rows[0] || null;
};

/**
 * Lấy nhiều địa điểm đang hoạt động theo danh sách ID.
 *
 * Được dùng cho chức năng tối ưu lộ trình.
 */
const findActivePlacesByIds = async (placeIds) => {
    if (!Array.isArray(placeIds) || placeIds.length === 0) {
        return [];
    }

    const query = `
    SELECT ${PLACE_COLUMNS}
    FROM places
    WHERE id = ANY($1::UUID[])
      AND is_active = TRUE;
  `;

    const { rows } = await db.query(query, [placeIds]);
    return rows;
};

/**
 * Admin tạo địa điểm mới.
 */
const createPlace = async ({
    name,
    destination,
    address = null,
    category,
    latitude = null,
    longitude = null,
    imageUrl = null,
    priceLevel = 1,
    avgDurationMinutes = 60,
}) => {
    const query = `
    INSERT INTO places (
      name,
      destination,
      address,
      category,
      latitude,
      longitude,
      image_url,
      price_level,
      avg_duration_minutes
    )
    VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9
    )
    RETURNING ${PLACE_COLUMNS};
  `;

    const values = [
        name,
        destination,
        address,
        category,
        latitude,
        longitude,
        imageUrl,
        priceLevel,
        avgDurationMinutes,
    ];

    const { rows } = await db.query(query, values);
    return rows[0];
};

/**
 * Admin cập nhật thông tin hoặc ảnh địa điểm.
 *
 * Chỉ các cột có trong whitelist mới có thể được cập nhật.
 */
const updatePlace = async (placeId, placeData) => {
    const columnMap = {
        name: 'name',
        destination: 'destination',
        address: 'address',
        category: 'category',
        latitude: 'latitude',
        longitude: 'longitude',
        imageUrl: 'image_url',
        priceLevel: 'price_level',
        avgDurationMinutes: 'avg_duration_minutes',
    };

    const updates = [];
    const values = [placeId];

    for (const [field, column] of Object.entries(columnMap)) {
        if (placeData[field] !== undefined) {
            values.push(placeData[field]);
            updates.push(`${column} = $${values.length}`);
        }
    }

    if (updates.length === 0) {
        return findPlaceById(placeId, {
            includeInactive: true,
        });
    }

    const query = `
    UPDATE places
    SET ${updates.join(', ')}
    WHERE id = $1
    RETURNING ${PLACE_COLUMNS};
  `;

    const { rows } = await db.query(query, values);
    return rows[0] || null;
};

/**
 * Admin ẩn hoặc khôi phục địa điểm.
 *
 * Không xóa vật lý để các lịch trình cũ vẫn giữ được liên kết.
 */
const updatePlaceStatus = async ({
    placeId,
    isActive,
}) => {
    const query = `
    UPDATE places
    SET is_active = $2
    WHERE id = $1
    RETURNING ${PLACE_COLUMNS};
  `;

    const { rows } = await db.query(query, [
        placeId,
        isActive,
    ]);

    return rows[0] || null;
};

/**
 * Kiểm tra địa điểm trùng tên trong cùng một tỉnh/thành.
 * So sánh không phân biệt hoa/thường và khoảng trắng thừa.
 */
const findPlaceByNameAndDestination = async (
    name,
    destination,
    excludeId = null
) => {
    let query = `
    SELECT ${PLACE_COLUMNS}
    FROM places
    WHERE LOWER(TRIM(name)) = LOWER(TRIM($1))
      AND LOWER(TRIM(destination)) = LOWER(TRIM($2))
  `;
    const values = [name, destination];

    if (excludeId) {
        values.push(excludeId);
        query += ` AND id != $${values.length}`;
    }

    query += ' LIMIT 1;';

    const { rows } = await db.query(query, values);
    return rows[0] || null;
};

/**
 * Kiểm tra địa điểm trùng tọa độ (dung sai khoảng 1 mét: ~0.00001 độ).
 */
const findPlaceByCoordinates = async (
    latitude,
    longitude,
    excludeId = null
) => {
    if (
        latitude === null ||
        latitude === undefined ||
        longitude === null ||
        longitude === undefined
    ) {
        return null;
    }

    let query = `
    SELECT ${PLACE_COLUMNS}
    FROM places
    WHERE latitude IS NOT NULL
      AND longitude IS NOT NULL
      AND ABS(latitude - $1) < 0.00001
      AND ABS(longitude - $2) < 0.00001
  `;
    const values = [Number(latitude), Number(longitude)];

    if (excludeId) {
        values.push(excludeId);
        query += ` AND id != $${values.length}`;
    }

    query += ' LIMIT 1;';

    const { rows } = await db.query(query, values);
    return rows[0] || null;
};

module.exports = {
    findPlaces,
    findPlaceById,
    findActivePlacesByIds,
    findPlaceByNameAndDestination,
    findPlaceByCoordinates,
    createPlace,
    updatePlace,
    updatePlaceStatus,
};