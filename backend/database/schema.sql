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
    terms_version VARCHAR(32),
    terms_accepted_at TIMESTAMPTZ,
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE, -- Tích xanh eKYC CCCD
    verification_status VARCHAR(20) DEFAULT 'UNVERIFIED' 
        CHECK (verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED')),
    verification_rejection_reason VARCHAR(500), -- Lý do từ chối eKYC gần nhất; xóa khi nộp lại/duyệt
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
    invite_code_status VARCHAR(10) NOT NULL DEFAULT 'NONE', -- NONE / ACTIVE / USED / REVOKED; migration 003 adds synchronization and constraint
    
    -- Tính năng Clone / Fork Plan của cộng đồng
    is_clone BOOLEAN DEFAULT FALSE,
    original_trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
    clone_count INT DEFAULT 0,

    -- Tọa độ điểm đến Geoapify
    destination_provider VARCHAR(30),
    destination_external_id VARCHAR(255),
    destination_latitude DOUBLE PRECISION,
    destination_longitude DOUBLE PRECISION,
    CONSTRAINT chk_trips_destination_coordinates CHECK (
        (destination_latitude IS NULL AND destination_longitude IS NULL)
        OR (
            destination_latitude BETWEEN -90 AND 90
            AND destination_longitude BETWEEN -180 AND 180
        )
    ),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trip_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER' CHECK (role IN ('LEADER', 'MEMBER')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    membership_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT trip_members_membership_status_check
        CHECK (membership_status IN ('ACTIVE', 'LEFT', 'REMOVED')),
    left_at TIMESTAMPTZ,
    removed_at TIMESTAMPTZ,
    removed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE(trip_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_trip_members_trip_status
    ON trip_members(trip_id, membership_status);

-- Lời mời đích danh; thông báo chỉ hiển thị sự kiện, không giữ trạng thái lời mời.
CREATE TABLE IF NOT EXISTS trip_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES users(id),
    invitee_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CONSTRAINT trip_invitations_status_check
        CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'REVOKED', 'EXPIRED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    CONSTRAINT trip_invitations_not_self_check CHECK (inviter_id <> invitee_id),
    CONSTRAINT trip_invitations_expiry_check
        CHECK (expires_at IS NULL OR expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS idx_trip_invitations_invitee_status
    ON trip_invitations(invitee_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_trip_invitations_trip_status
    ON trip_invitations(trip_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_invitations_one_pending
    ON trip_invitations(trip_id, invitee_id) WHERE status = 'PENDING';
ALTER TABLE trip_invitations ENABLE ROW LEVEL SECURITY;

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
        'ATTRACTION', 'RESTAURANT', 'CAFE', 'HOTEL', 'ENTERTAINMENT', 'NATURE', 'CULTURE', 'SHOPPING', 'OTHER'
    )),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    image_url TEXT,
    price_level INT DEFAULT 1 CHECK (price_level BETWEEN 1 AND 4), -- 1: Rẻ, 4: Rất đắt
    avg_duration_minutes INT DEFAULT 60,
    rating NUMERIC(3, 2) DEFAULT 5.0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- FALSE: ẩn; TRUE: hiển thị/khôi phục
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
    location_source VARCHAR(20) NOT NULL DEFAULT 'MANUAL',
    external_provider VARCHAR(30),
    external_place_id VARCHAR(255),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_itinerary_items_location_source CHECK (location_source IN ('CATALOG', 'GEOAPIFY', 'MANUAL')),
    CONSTRAINT chk_itinerary_items_latitude_range CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_itinerary_items_longitude_range CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_itinerary_items_coordinates_paired CHECK (
        (latitude IS NULL AND longitude IS NULL)
        OR (latitude IS NOT NULL AND longitude IS NOT NULL)
    ),
    CONSTRAINT chk_itinerary_items_place_id_source CHECK (
        place_id IS NULL OR location_source = 'CATALOG'
    ),
    CONSTRAINT chk_itinerary_items_geoapify_complete CHECK (
        location_source <> 'GEOAPIFY'
        OR (
            external_provider = 'GEOAPIFY'
            AND external_place_id IS NOT NULL
            AND latitude IS NOT NULL
            AND longitude IS NOT NULL
        )
    )
);

-- ============================================================================
-- 4. BẢNG QUẢN LÝ CHI PHÍ, CHIA TIỀN (SPLIT BILL) & VIETQR
-- ============================================================================
-- Khoản chi tiêu chung trong chuyến đi
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    payer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Người đứng ra trả tiền trước
    itinerary_item_id UUID REFERENCES itinerary_items(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL CHECK (amount >= 0),
    category VARCHAR(50) DEFAULT 'OTHER' CHECK (category IN (
        'FOOD', 'TRANSPORTATION', 'ACCOMMODATION', 'TICKETS', 'SHOPPING', 'OTHER'
    )),
    receipt_image_url TEXT, -- Ảnh hóa đơn thanh toán
    expense_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Bảng phân bổ chi phí cho từng thành viên (Ai phải chịu bao nhiêu tiền trong khoản chi đó)
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS itinerary_item_id UUID
  REFERENCES itinerary_items(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_itinerary_item
  ON expenses(itinerary_item_id) WHERE itinerary_item_id IS NOT NULL;
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
    evidence_image_url TEXT, -- API: evidenceImageUrl; URL ảnh đã upload
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

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS trg_trips_updated_at ON trips;
CREATE TRIGGER trg_trips_updated_at BEFORE UPDATE ON trips FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS trg_companion_posts_updated_at ON companion_posts;
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
CREATE INDEX IF NOT EXISTS idx_itinerary_items_external_place ON itinerary_items(external_provider, external_place_id) WHERE external_place_id IS NOT NULL;

-- Backend integrity additions (also available as migration 001).
-- Run via npm run db:migrate on an existing database. No application data is deleted.
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;
CREATE TABLE IF NOT EXISTS auth_otps (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose TEXT NOT NULL CHECK (purpose IN ('VERIFY_EMAIL','FORGOT_PASSWORD')),
  otp_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  PRIMARY KEY (user_id, purpose)
);
CREATE TABLE IF NOT EXISTS request_limits (
  key TEXT PRIMARY KEY, hits INTEGER NOT NULL, expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_request_limits_expiry ON request_limits(expires_at);
CREATE OR REPLACE FUNCTION revoke_tokens_on_status_change() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN NEW.token_version := OLD.token_version + 1; END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_users_revoke_tokens ON users;
CREATE TRIGGER trg_users_revoke_tokens BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION revoke_tokens_on_status_change();

ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_check;
ALTER TABLE settlements ADD CONSTRAINT settlements_status_check
  CHECK (status IN ('PENDING','REPORTED','PAID','CANCELLED'));
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS reported_at TIMESTAMPTZ;
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS bank_bin VARCHAR(20);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS bank_account_number VARCHAR(50);
ALTER TABLE settlements ADD COLUMN IF NOT EXISTS bank_account_name VARCHAR(100);
UPDATE settlements s SET bank_bin = u.bank_bin, bank_account_number = u.bank_account_number,
  bank_account_name = u.bank_account_name
  FROM users u WHERE u.id = s.to_user_id AND s.bank_bin IS NULL AND s.bank_account_number IS NULL;
CREATE TABLE IF NOT EXISTS sepay_events (
  transaction_id TEXT PRIMARY KEY,
  settlement_id UUID NOT NULL REFERENCES settlements(id),
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE places DROP CONSTRAINT IF EXISTS places_category_check;
ALTER TABLE places ADD CONSTRAINT places_category_check CHECK (category IN (
  'ATTRACTION','RESTAURANT','CAFE','HOTEL','ENTERTAINMENT','NATURE','CULTURE','SHOPPING','OTHER'
));

-- Shared storage contract for Thanh's reviews/SOS feature; routes stay with its owner.
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  full_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  relationship VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
  latitude DOUBLE PRECISION NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  message VARCHAR(500),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','RESOLVED','FALSE_ALARM')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user ON emergency_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_sos_alerts_user ON sos_alerts(user_id);

ALTER TABLE itinerary_items ADD COLUMN IF NOT EXISTS category VARCHAR(50) NOT NULL DEFAULT 'OTHER';

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));

-- One review per target per trip; NULL reviewee_id means a review of the trip.
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_reviews_member_unique
  ON trip_reviews (trip_id, reviewer_id, reviewee_id) WHERE reviewee_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_trip_reviews_trip_unique
  ON trip_reviews (trip_id, reviewer_id) WHERE reviewee_id IS NULL;

-- ============================================================
-- Admin Itinerary Templates (migration 009)
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_itinerary_templates (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  name             VARCHAR(255)  NOT NULL,
  destination      VARCHAR(100)  NOT NULL,
  duration_days    INT           NOT NULL CHECK (duration_days BETWEEN 1 AND 30),
  estimated_budget NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (estimated_budget >= 0),
  description      TEXT,
  cover_image_url  TEXT,
  days             JSONB         NOT NULL CHECK (jsonb_typeof(days) = 'array'),
  is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
  created_by       UUID          NOT NULL REFERENCES users(id),
  source_trip_id   UUID          REFERENCES trips(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS admin_template_uses (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID        NOT NULL REFERENCES admin_itinerary_templates(id) ON DELETE RESTRICT,
  trip_id     UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  used_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ait_destination
  ON admin_itinerary_templates (LOWER(destination));
CREATE INDEX IF NOT EXISTS idx_ait_is_active
  ON admin_itinerary_templates (is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_atu_template_id
  ON admin_template_uses (template_id);
CREATE INDEX IF NOT EXISTS idx_atu_user_template
  ON admin_template_uses (user_id, template_id);
