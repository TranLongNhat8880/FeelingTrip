const placesRepository = require('./places.repository');
const apiError = require('../../shared/utils/apiError.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// SERVICE: Places & Maps
// Xử lý nghiệp vụ, khoảng cách và tối ưu thứ tự địa điểm.
// ============================================================================

const EARTH_RADIUS_KM = 6371;

/**
 * Tốc độ trung bình chỉ dùng để ước lượng thời gian.
 * Đây không phải dữ liệu giao thông thời gian thực.
 */
const AVERAGE_SPEED_KMH = {
    driving: 30,
    walking: 5,
    bicycling: 15,
    transit: 25,
};

/**
 * Chuyển dữ liệu DB snake_case thành API camelCase.
 */
const mapPlace = (place) => {
    const hasCoordinates =
        place.latitude !== null &&
        place.longitude !== null;

    return {
        id: place.id,
        name: place.name,
        destination: place.destination,
        address: place.address,
        category: place.category,
        latitude: place.latitude,
        longitude: place.longitude,
        imageUrl: place.image_url,
        priceLevel: place.price_level,
        avgDurationMinutes: place.avg_duration_minutes,
        rating: Number(place.rating),
        isActive: place.is_active,
        mapUrl: hasCoordinates
            ? buildMapSearchUrl(
                place.latitude,
                place.longitude
            )
            : null,
        createdAt: place.created_at,
    };
};

/**
 * Đổi độ sang radian.
 */
const toRadians = (degrees) =>
    (degrees * Math.PI) / 180;

/**
 * Tính khoảng cách đường chim bay bằng công thức Haversine.
 */
const calculateHaversineDistance = (
    originLat,
    originLng,
    destinationLat,
    destinationLng
) => {
    const latitudeDifference = toRadians(
        destinationLat - originLat
    );

    const longitudeDifference = toRadians(
        destinationLng - originLng
    );

    const originLatitude = toRadians(originLat);
    const destinationLatitude =
        toRadians(destinationLat);

    const haversineValue =
        Math.sin(latitudeDifference / 2) ** 2 +
        Math.cos(originLatitude) *
        Math.cos(destinationLatitude) *
        Math.sin(longitudeDifference / 2) ** 2;

    const angularDistance =
        2 *
        Math.atan2(
            Math.sqrt(haversineValue),
            Math.sqrt(1 - haversineValue)
        );

    return EARTH_RADIUS_KM * angularDistance;
};

/**
 * Ước lượng thời gian di chuyển từ khoảng cách và loại phương tiện.
 */
const estimateTravelMinutes = (
    distanceKm,
    travelMode
) => {
    if (distanceKm === 0) {
        return 0;
    }

    const speed =
        AVERAGE_SPEED_KMH[travelMode] ||
        AVERAGE_SPEED_KMH.driving;

    return Math.ceil((distanceKm / speed) * 60);
};

/**
 * Tạo URL mở một tọa độ trên Google Maps.
 * Google Maps URL không yêu cầu API key.
 */
function buildMapSearchUrl(latitude, longitude) {
    const params = new URLSearchParams({
        api: '1',
        query: `${latitude},${longitude}`,
    });

    return `https://www.google.com/maps/search/?${params.toString()}`;
}

/**
 * Tạo URL mở chỉ đường giữa hai tọa độ.
 */
const buildDirectionsUrl = ({
    originLat,
    originLng,
    destinationLat,
    destinationLng,
    travelMode,
}) => {
    const params = new URLSearchParams({
        api: '1',
        origin: `${originLat},${originLng}`,
        destination:
            `${destinationLat},${destinationLng}`,
        travelmode: travelMode,
    });

    return `https://www.google.com/maps/dir/?${params.toString()}`;
};

/**
 * Tạo URL chỉ đường qua nhiều địa điểm.
 */
const buildMultiPlaceDirectionsUrl = (
    orderedPlaces,
    travelMode
) => {
    if (orderedPlaces.length < 2) {
        return null;
    }

    const origin = orderedPlaces[0];
    const destination =
        orderedPlaces[orderedPlaces.length - 1];

    const params = new URLSearchParams({
        api: '1',
        origin:
            `${origin.latitude},${origin.longitude}`,
        destination:
            `${destination.latitude},${destination.longitude}`,
        travelmode: travelMode,
    });

    const waypoints = orderedPlaces.slice(1, -1);

    if (waypoints.length > 0) {
        params.set(
            'waypoints',
            waypoints
                .map(
                    (place) =>
                        `${place.latitude},${place.longitude}`
                )
                .join('|')
        );
    }

    return `https://www.google.com/maps/dir/?${params.toString()}`;
};

/**
 * Tìm kiếm địa điểm công khai.
 * Repository luôn loại bỏ địa điểm đã bị ẩn.
 */
const searchPlaces = async (filters) => {
    const result = await placesRepository.findPlaces(
        filters
    );

    return {
        items: result.places.map(mapPlace),
        pagination: {
            page: filters.page,
            limit: filters.limit,
            total: result.total,
            totalPages: Math.ceil(
                result.total / filters.limit
            ),
        },
    };
};

/**
 * Danh sách quản lý cho Admin.
 * Có thể xem cả địa điểm đang hoạt động và đã bị ẩn.
 */
const getManagePlaces = async (filters) => {
    const result = await placesRepository.findPlaces(
        filters,
        {
            includeInactive: true,
        }
    );

    return {
        items: result.places.map(mapPlace),
        pagination: {
            page: filters.page,
            limit: filters.limit,
            total: result.total,
            totalPages: Math.ceil(
                result.total / filters.limit
            ),
        },
    };
};

/**
 * Xem chi tiết địa điểm công khai.
 */
const getPlaceById = async (placeId) => {
    const place =
        await placesRepository.findPlaceById(placeId);

    if (!place) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy địa điểm'
        );
    }

    return mapPlace(place);
};

/**
 * Admin tạo địa điểm mới.
 */
const createPlace = async ({
    placeData,
    imageUrl,
}) => {
    // 1. Kiểm tra trùng tên trong cùng một tỉnh/thành
    if (placeData.name && placeData.destination) {
        const existingByName =
            await placesRepository.findPlaceByNameAndDestination(
                placeData.name,
                placeData.destination
            );

        if (existingByName) {
            throw apiError(
                HTTP_STATUS.CONFLICT,
                `Địa điểm "${placeData.name}" đã tồn tại tại ${placeData.destination}`
            );
        }
    }

    // 2. Kiểm tra trùng tọa độ nếu có cung cấp
    if (
        placeData.latitude !== undefined &&
        placeData.latitude !== null &&
        placeData.longitude !== undefined &&
        placeData.longitude !== null
    ) {
        const existingByCoords =
            await placesRepository.findPlaceByCoordinates(
                placeData.latitude,
                placeData.longitude
            );

        if (existingByCoords) {
            throw apiError(
                HTTP_STATUS.CONFLICT,
                `Tọa độ này đã trùng với địa điểm "${existingByCoords.name}" tại ${existingByCoords.destination}`
            );
        }
    }

    const normalizedData = {
        ...placeData,
        address:
            placeData.address === ''
                ? null
                : placeData.address,
        imageUrl: imageUrl || null,
    };

    const place =
        await placesRepository.createPlace(
            normalizedData
        );

    return mapPlace(place);
};

/**
 * Admin cập nhật địa điểm hoặc thay ảnh.
 */
const updatePlace = async ({
    placeId,
    placeData,
    imageUrl,
}) => {
    const existingPlace =
        await placesRepository.findPlaceById(
            placeId,
            {
                includeInactive: true,
            }
        );

    if (!existingPlace) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy địa điểm'
        );
    }

    const targetName =
        placeData.name !== undefined
            ? placeData.name
            : existingPlace.name;
    const targetDestination =
        placeData.destination !== undefined
            ? placeData.destination
            : existingPlace.destination;

    // 1. Kiểm tra trùng tên nếu có thay đổi name hoặc destination
    if (
        (placeData.name !== undefined ||
            placeData.destination !== undefined) &&
        targetName &&
        targetDestination
    ) {
        const existingByName =
            await placesRepository.findPlaceByNameAndDestination(
                targetName,
                targetDestination,
                placeId
            );

        if (existingByName) {
            throw apiError(
                HTTP_STATUS.CONFLICT,
                `Địa điểm "${targetName}" đã tồn tại tại ${targetDestination}`
            );
        }
    }

    // 2. Kiểm tra trùng tọa độ nếu có thay đổi latitude hoặc longitude
    const targetLat =
        placeData.latitude !== undefined
            ? placeData.latitude
            : existingPlace.latitude;
    const targetLng =
        placeData.longitude !== undefined
            ? placeData.longitude
            : existingPlace.longitude;

    if (
        (placeData.latitude !== undefined ||
            placeData.longitude !== undefined) &&
        targetLat !== null &&
        targetLng !== null
    ) {
        const existingByCoords =
            await placesRepository.findPlaceByCoordinates(
                targetLat,
                targetLng,
                placeId
            );

        if (existingByCoords) {
            throw apiError(
                HTTP_STATUS.CONFLICT,
                `Tọa độ này đã trùng với địa điểm "${existingByCoords.name}" tại ${existingByCoords.destination}`
            );
        }
    }

    const updateData = { ...placeData };

    if (updateData.address === '') {
        updateData.address = null;
    }

    if (imageUrl !== undefined) {
        updateData.imageUrl = imageUrl;
    }

    const hasUpdate = Object.values(
        updateData
    ).some((value) => value !== undefined);

    if (!hasUpdate) {
        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            'Vui lòng cung cấp thông tin hoặc ảnh cần cập nhật'
        );
    }

    const updatedPlace =
        await placesRepository.updatePlace(
            placeId,
            updateData
        );

    return mapPlace(updatedPlace);
};

/**
 * Admin ẩn hoặc khôi phục địa điểm.
 */
const updatePlaceStatus = async ({
    placeId,
    isActive,
}) => {
    const existingPlace =
        await placesRepository.findPlaceById(
            placeId,
            {
                includeInactive: true,
            }
        );

    if (!existingPlace) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Không tìm thấy địa điểm'
        );
    }

    if (existingPlace.is_active === isActive) {
        throw apiError(
            HTTP_STATUS.CONFLICT,
            isActive
                ? 'Địa điểm này đang ở trạng thái hoạt động'
                : 'Địa điểm này đã được ẩn'
        );
    }

    const updatedPlace =
        await placesRepository.updatePlaceStatus({
            placeId,
            isActive,
        });

    return mapPlace(updatedPlace);
};

/**
 * Tính khoảng cách giữa hai tọa độ.
 *
 * distanceKm là khoảng cách đường chim bay.
 * estimatedDurationMinutes chỉ là thời gian ước lượng.
 */
const calculateDistance = ({
    originLat,
    originLng,
    destLat,
    destLng,
    travelMode,
}) => {
    const rawDistance =
        calculateHaversineDistance(
            originLat,
            originLng,
            destLat,
            destLng
        );

    const distanceKm = Number(
        rawDistance.toFixed(2)
    );

    return {
        origin: {
            latitude: originLat,
            longitude: originLng,
        },
        destination: {
            latitude: destLat,
            longitude: destLng,
        },
        travelMode,
        distanceKm,
        estimatedDurationMinutes:
            estimateTravelMinutes(
                rawDistance,
                travelMode
            ),
        calculationMethod: 'HAVERSINE_ESTIMATE',
        directionsUrl: buildDirectionsUrl({
            originLat,
            originLng,
            destinationLat: destLat,
            destinationLng: destLng,
            travelMode,
        }),
    };
};

/**
 * Tối ưu thứ tự ghé thăm bằng Nearest Neighbor.
 *
 * Thuật toán chọn địa điểm gần nhất tiếp theo.
 * Đây là phương án gợi ý, không cam kết tối ưu tuyệt đối.
 */
const optimizeRoute = async ({
    placeIds,
    startPlaceId,
    travelMode,
}) => {
    if (
        startPlaceId &&
        !placeIds.includes(startPlaceId)
    ) {
        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            'startPlaceId phải nằm trong danh sách placeIds'
        );
    }

    const places =
        await placesRepository.findActivePlacesByIds(
            placeIds
        );

    const placeMap = new Map(
        places.map((place) => [place.id, place])
    );

    const missingPlaceIds = placeIds.filter(
        (placeId) => !placeMap.has(placeId)
    );

    if (missingPlaceIds.length > 0) {
        throw apiError(
            HTTP_STATUS.NOT_FOUND,
            'Có địa điểm không tồn tại hoặc đã bị ẩn'
        );
    }

    // Khôi phục đúng thứ tự placeIds do PostgreSQL không bảo đảm
    // thứ tự kết quả của câu lệnh ANY.
    const orderedInputPlaces = placeIds.map(
        (placeId) => placeMap.get(placeId)
    );

    const placesWithoutCoordinates =
        orderedInputPlaces.filter(
            (place) =>
                place.latitude === null ||
                place.longitude === null
        );

    if (placesWithoutCoordinates.length > 0) {
        const placeNames = placesWithoutCoordinates
            .map((place) => place.name)
            .join(', ');

        throw apiError(
            HTTP_STATUS.BAD_REQUEST,
            `Các địa điểm chưa có tọa độ: ${placeNames}`
        );
    }

    const firstPlaceId =
        startPlaceId || placeIds[0];

    let currentPlace = placeMap.get(firstPlaceId);

    const remainingPlaces =
        orderedInputPlaces.filter(
            (place) => place.id !== firstPlaceId
        );

    const optimizedPlaces = [currentPlace];
    const routeLegs = [];

    let totalDistanceKm = 0;
    let estimatedTravelDurationMinutes = 0;

    while (remainingPlaces.length > 0) {
        let nearestIndex = 0;
        let nearestDistance =
            Number.POSITIVE_INFINITY;

        for (
            let index = 0;
            index < remainingPlaces.length;
            index += 1
        ) {
            const candidate = remainingPlaces[index];

            const candidateDistance =
                calculateHaversineDistance(
                    currentPlace.latitude,
                    currentPlace.longitude,
                    candidate.latitude,
                    candidate.longitude
                );

            if (candidateDistance < nearestDistance) {
                nearestDistance = candidateDistance;
                nearestIndex = index;
            }
        }

        const [nearestPlace] =
            remainingPlaces.splice(nearestIndex, 1);

        const legDuration =
            estimateTravelMinutes(
                nearestDistance,
                travelMode
            );

        routeLegs.push({
            fromPlaceId: currentPlace.id,
            fromPlaceName: currentPlace.name,
            toPlaceId: nearestPlace.id,
            toPlaceName: nearestPlace.name,
            distanceKm: Number(
                nearestDistance.toFixed(2)
            ),
            estimatedDurationMinutes:
                legDuration,
        });

        totalDistanceKm += nearestDistance;
        estimatedTravelDurationMinutes +=
            legDuration;

        optimizedPlaces.push(nearestPlace);
        currentPlace = nearestPlace;
    }

    const totalVisitDurationMinutes =
        optimizedPlaces.reduce(
            (total, place) =>
                total +
                (place.avg_duration_minutes || 0),
            0
        );

    return {
        algorithm: 'NEAREST_NEIGHBOR',
        calculationMethod: 'HAVERSINE_ESTIMATE',
        travelMode,
        orderedPlaces:
            optimizedPlaces.map(mapPlace),
        legs: routeLegs,
        totalDistanceKm: Number(
            totalDistanceKm.toFixed(2)
        ),
        estimatedTravelDurationMinutes,
        totalVisitDurationMinutes,
        estimatedTotalDurationMinutes:
            estimatedTravelDurationMinutes +
            totalVisitDurationMinutes,
        directionsUrl:
            buildMultiPlaceDirectionsUrl(
                optimizedPlaces,
                travelMode
            ),
    };
};

module.exports = {
    searchPlaces,
    getManagePlaces,
    getPlaceById,
    createPlace,
    updatePlace,
    updatePlaceStatus,
    calculateDistance,
    optimizeRoute,
};