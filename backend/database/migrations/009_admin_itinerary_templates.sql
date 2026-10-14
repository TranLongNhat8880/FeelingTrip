-- Migration 009: Admin Itinerary Templates
-- Tạo bảng lịch trình mẫu do admin quản lý và bảng log sử dụng mẫu.
-- Các bảng này phục vụ tính năng "Kho lịch trình" cho người dùng.

SET LOCAL lock_timeout = '10s';

-- ============================================================
-- Bảng chính: lịch trình mẫu do admin tạo
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_itinerary_templates (
  id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  name             VARCHAR(255)  NOT NULL,
  destination      VARCHAR(100)  NOT NULL,
  duration_days    INT           NOT NULL CHECK (duration_days BETWEEN 1 AND 30),
  estimated_budget NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (estimated_budget >= 0),
  description      TEXT,
  cover_image_url  TEXT,
  -- days lưu toàn bộ lịch trình dạng JSON; mỗi phần tử là một ngày với danh sách items
  days             JSONB         NOT NULL CHECK (jsonb_typeof(days) = 'array'),
  is_active        BOOLEAN       NOT NULL DEFAULT TRUE,
  created_by       UUID          NOT NULL REFERENCES users(id),
  -- Nếu template được import từ chuyến đi cộng đồng thì lưu lại nguồn gốc
  source_trip_id   UUID          REFERENCES trips(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Bảng log: theo dõi ai đã áp dụng mẫu nào vào chuyến đi nào
-- ============================================================
CREATE TABLE IF NOT EXISTS admin_template_uses (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID        NOT NULL REFERENCES admin_itinerary_templates(id) ON DELETE RESTRICT,
  trip_id     UUID        NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  used_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Indexes
-- ============================================================

-- Tìm kiếm theo điểm đến
CREATE INDEX IF NOT EXISTS idx_ait_destination
  ON admin_itinerary_templates (LOWER(destination));

-- Lọc theo trạng thái hoạt động (kho lịch trình người dùng chỉ thấy bản active)
CREATE INDEX IF NOT EXISTS idx_ait_is_active
  ON admin_itinerary_templates (is_active, created_at DESC);

-- Đếm lượt sử dụng nhanh theo template
CREATE INDEX IF NOT EXISTS idx_atu_template_id
  ON admin_template_uses (template_id);

-- Kiểm tra người dùng đã dùng mẫu này chưa (tránh spam apply)
CREATE INDEX IF NOT EXISTS idx_atu_user_template
  ON admin_template_uses (user_id, template_id);
