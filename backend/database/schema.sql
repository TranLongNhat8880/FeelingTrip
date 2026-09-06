-- ============================================================================
-- FEELINGTRIP - POSTGRESQL DATABASE SCHEMA (COMPATIBLE WITH SUPABASE)
-- Mô tả: Cơ sở dữ liệu hoàn chỉnh cho ứng dụng lập kế hoạch du lịch & chia tiền
-- ============================================================================

-- Bật extension tạo UUID ngẫu nhiên
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. BẢNG USERS (NGƯỜI DÙNG & XÁC MINH eKYC)
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255), -- NULL nếu đăng nhập qua Google OAuth
    google_id VARCHAR(255) UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    nickname VARCHAR(50),
    phone VARCHAR(20),
    avatar_url TEXT,
    bio TEXT,
    gender VARCHAR(10) CHECK (gender IN ('MALE', 'FEMALE', 'OTHER')),
    dob DATE,
    
    -- Trạng thái xác thực
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE, -- Tích xanh eKYC CCCD
    verification_status VARCHAR(20) DEFAULT 'UNVERIFIED' 
        CHECK (verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED')),
    cccd_number VARCHAR(20),
    cccd_front_image TEXT,
    cccd_back_image TEXT,
    selfie_image TEXT,
    
    -- Thông tin thụ hưởng ngân hàng (Dùng cho VietQR & Split Bill)
    bank_bin VARCHAR(20),          -- Mã định danh ngân hàng (VD: 970422 - MB, 970436 - VCB)
    bank_name VARCHAR(100),        -- Tên ngân hàng (VD: MB Bank, Vietcombank)
    bank_account_number VARCHAR(50), -- Số tài khoản
    bank_account_name VARCHAR(100),  -- Tên chủ tài khoản (in hoa không dấu)
    
    -- Phân quyền hệ thống
    role VARCHAR(20) DEFAULT 'USER' CHECK (role IN ('USER', 'ADMIN')),
    status VARCHAR(20) DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'BANNED')),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. BẢNG TRIPS & THÀNH VIÊN NHÓM
-- ============================================================================
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    duration_days INT GENERATED ALWAYS AS (end_date - start_date + 1) STORED,
    estimated_budget NUMERIC(15, 2) DEFAULT 0,
    cover_image_url TEXT,
    description TEXT,
    
    -- Trạng thái & Quyền riêng tư
    privacy_type VARCHAR(20) DEFAULT 'PRIVATE' CHECK (privacy_type IN ('PRIVATE', 'PUBLIC')),
    status VARCHAR(20) DEFAULT 'UPCOMING' CHECK (status IN ('UPCOMING', 'ONGOING', 'COMPLETED', 'CANCELLED')),
    invite_code VARCHAR(20) UNIQUE, -- Mã ngắn để bạn bè tham gia nhóm (VD: TRIP-8A9F)
    
    -- Tính năng Clone / Fork Plan của cộng đồng
    is_clone BOOLEAN DEFAULT FALSE,
    original_trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
    clone_count INT DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trip_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER' CHECK (role IN ('LEADER', 'MEMBER')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(trip_id, user_id)
);

-- ============================================================================
-- 3. BẢNG ĐỊA ĐIỂM (PLACES) & LỊCH TRÌNH THEO NGÀY (ITINERARIES)
-- ============================================================================
-- Kho địa điểm chuẩn phục vụ tìm kiếm & Smart Swap B -> B+
CREATE TABLE IF NOT EXISTS places (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    destination VARCHAR(100) NOT NULL, -- TP/Tỉnh (VD: Da Lat, Ha Noi, Da Nang)
    address TEXT,
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'ATTRACTION', 'RESTAURANT', 'CAFE', 'HOTEL', 'ENTERTAINMENT', 'NATURE', 'CULTURE', 'OTHER'
    )),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    image_url TEXT,
    price_level INT DEFAULT 1 CHECK (price_level BETWEEN 1 AND 4), -- 1: Rẻ, 4: Rất đắt
    avg_duration_minutes INT DEFAULT 60,
    rating NUMERIC(3, 2) DEFAULT 5.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Các ngày trong chuyến đi (Day 1, Day 2...)
CREATE TABLE IF NOT EXISTS itineraries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    day_number INT NOT NULL, -- Ngày 1, Ngày 2...
    title VARCHAR(255),      -- Tiêu đề ngày (VD: Check-in trung tâm & ngắm hoàng hôn)
    trip_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(trip_id, day_number)
);

-- Chi tiết từng hoạt động/địa điểm dừng chân trong ngày
CREATE TABLE IF NOT EXISTS itinerary_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
    place_id UUID REFERENCES places(id) ON DELETE SET NULL, -- Có thể liên kết với kho place hoặc tự tạo
    custom_name VARCHAR(255) NOT NULL,
    custom_address TEXT,
    start_time TIME,
    end_time TIME,
    order_index INT NOT NULL DEFAULT 0, -- Thứ tự di chuyển trong ngày (1, 2, 3...)
    note TEXT,
    estimated_cost NUMERIC(15, 2) DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 4. BẢNG QUẢN LÝ CHI PHÍ, CHIA TIỀN (SPLIT BILL) & VIETQR
-- ============================================================================
-- Khoản chi tiêu chung trong chuyến đi
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    payer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Người đứng ra trả tiền trước
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    category VARCHAR(50) DEFAULT 'OTHER' CHECK (category IN (
        'FOOD', 'TRANSPORTATION', 'ACCOMMODATION', 'TICKETS', 'SHOPPING', 'OTHER'
    )),
    receipt_image_url TEXT, -- Ảnh hóa đơn thanh toán
    expense_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Bảng phân bổ chi phí cho từng thành viên (Ai phải chịu bao nhiêu tiền trong khoản chi đó)
CREATE TABLE IF NOT EXISTS expense_splits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_owed NUMERIC(15, 2) NOT NULL CHECK (amount_owed >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(expense_id, user_id)
);

-- Bảng kết quả rút gọn nợ (Settlements) - Tính toán bằng thuật toán Min Cash Flow
CREATE TABLE IF NOT EXISTS settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Người nợ
    to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,   -- Người nhận
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID')),
    vietqr_url TEXT, -- Link ảnh VietQR tự động sinh để quét thanh toán
    paid_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 5. BẢNG BẢNG TIN TÌM BẠN ĐỒNG HÀNH (COMPANION NEWSFEED)
-- ============================================================================
CREATE TABLE IF NOT EXISTS companion_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    target_members_count INT NOT NULL CHECK (target_members_count > 0),
    current_members_count INT DEFAULT 1,
    status VARCHAR(20) DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'FULL', 'CLOSED')),
    
    -- Tiêu chí tuyển bạn đồng hành
    min_age INT,
    max_age INT,
    gender_preference VARCHAR(10) DEFAULT 'ANY' CHECK (gender_preference IN ('ANY', 'MALE', 'FEMALE')),
    tags TEXT[], -- Mảng các tag: ARRAY['Phượt', 'Ăn uống', 'Chill', 'Sống ảo']
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Yêu cầu xin gia nhập chuyến đi
CREATE TABLE IF NOT EXISTS companion_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES companion_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    introduction TEXT, -- Lời chào / Giới thiệu bản thân
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id)
);

-- ============================================================================
-- 6. BẢNG ĐÁNH GIÁ (REVIEWS) & BÁO CÁO VI PHẠM (REPORTS)
-- ============================================================================
CREATE TABLE IF NOT EXISTS trip_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reviewee_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Người được đánh giá (nếu đánh giá bạn đồng hành)
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reported_trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'RESOLVED', 'DISMISSED')),
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 6.3 BẢNG NOTIFICATIONS (THÔNG BÁO HỆ THỐNG & IN-APP)
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- INVITE, REQUEST, BILL, TRIP_UPDATE, SYSTEM
    data JSONB DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 7. TỰ ĐỘNG CẬP NHẬT UPDATED_AT (TRIGGER FUNCTION)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_trips_updated_at BEFORE UPDATE ON trips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_companion_posts_updated_at BEFORE UPDATE ON companion_posts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 8. INDEX TĂNG TỐC TRUY VẤN
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_trips_destination ON trips(destination);
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trip_members_user ON trip_members(user_id);
CREATE INDEX IF NOT EXISTS idx_itineraries_trip ON itineraries(trip_id);
CREATE INDEX IF NOT EXISTS idx_itinerary_items_itinerary ON itinerary_items(itinerary_id);
CREATE INDEX IF NOT EXISTS idx_expenses_trip ON expenses(trip_id);
CREATE INDEX IF NOT EXISTS idx_settlements_trip ON settlements(trip_id);
CREATE INDEX IF NOT EXISTS idx_companion_posts_status ON companion_posts(status);
CREATE INDEX IF NOT EXISTS idx_places_destination_category ON places(destination, category);
