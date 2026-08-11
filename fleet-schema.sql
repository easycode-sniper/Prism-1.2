-- ============================================================
-- FLEET OPERATIONS DATABASE SCHEMA
-- Supabase PostgreSQL with Row Level Security (RLS)
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- ENUM TYPES (for data integrity)
-- ============================================================

CREATE TYPE user_role AS ENUM ('admin', 'operator', 'viewer');
CREATE TYPE dispatch_status AS ENUM ('queued', 'active', 'completed', 'cancelled');
CREATE TYPE truck_status AS ENUM ('available', 'assigned', 'maintenance', 'offline');
CREATE TYPE notification_type AS ENUM ('info', 'warning', 'alert', 'critical');
CREATE TYPE event_type AS ENUM ('dispatch_created', 'dispatch_started', 'dispatch_completed', 'dispatch_cancelled', 'route_deviation', 'speed_violation', 'arrival', 'departure', 'geofence_enter', 'geofence_exit');

-- ============================================================
-- USER PROFILES (extends Supabase auth.users)
-- ============================================================

CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    role user_role DEFAULT 'viewer' NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Index for quick lookups
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_active ON profiles(is_active);

-- ============================================================
-- TRUCKS (Reference Data)
-- ============================================================

CREATE TABLE trucks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    truck_number TEXT UNIQUE NOT NULL,
    wialon_unit_id BIGINT,
    license_plate TEXT,
    capacity_kg DECIMAL(10,2),
    status truck_status DEFAULT 'available' NOT NULL,
    current_driver_id UUID,
    last_known_lat DECIMAL(9,6),
    last_known_lng DECIMAL(9,6),
    last_updated TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_trucks_number ON trucks(truck_number);
CREATE INDEX idx_trucks_wialon ON trucks(wialon_unit_id);
CREATE INDEX idx_trucks_status ON trucks(status);
CREATE INDEX idx_trucks_active ON trucks(is_active);

-- ============================================================
-- DRIVERS (Reference Data)
-- ============================================================

CREATE TABLE drivers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    license_number TEXT,
    wialon_driver_id BIGINT,
    rating_avg DECIMAL(3,2) DEFAULT 0.00,
    total_runs INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_drivers_name ON drivers(name);
CREATE INDEX idx_drivers_wialon ON drivers(wialon_driver_id);
CREATE INDEX idx_drivers_active ON drivers(is_active);

-- ============================================================
-- SITES (Reference Data - Clients, Construction Sites, etc.)
-- ============================================================

CREATE TABLE sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    site_type TEXT NOT NULL, -- 'construction', 'client', 'factory', 'gas_station', etc.
    address TEXT,
    lat DECIMAL(9,6) NOT NULL,
    lng DECIMAL(9,6) NOT NULL,
    radius_meters INTEGER DEFAULT 100,
    client_name TEXT,
    contact_phone TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_sites_name ON sites(name);
CREATE INDEX idx_sites_type ON sites(site_type);
CREATE INDEX idx_sites_location ON sites(lat, lng);
CREATE INDEX idx_sites_active ON sites(is_active);

-- Add geospatial index for proximity queries
ALTER TABLE sites ADD COLUMN location GEOGRAPHY(POINT, 4326);
CREATE INDEX idx_sites_geography ON sites USING GIST(location);

-- Update location column from lat/lng
UPDATE sites SET location = ST_MakePoint(lng, lat)::GEOGRAPHY WHERE location IS NULL;

-- ============================================================
-- GEOFENCES (Polygon boundaries for monitoring)
-- ============================================================

CREATE TABLE geofences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    geofence_type TEXT NOT NULL, -- 'allowed', 'restricted', 'monitoring'
    polygon GEOGRAPHY(POLYGON, 4326) NOT NULL,
    center_lat DECIMAL(9,6),
    center_lng DECIMAL(9,6),
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_geofences_name ON geofences(name);
CREATE INDEX idx_geofences_type ON geofences(geofence_type);
CREATE INDEX idx_geofences_active ON geofences(is_active);
CREATE INDEX idx_geofences_geometry ON geofences USING GIST(polygon);

-- ============================================================
-- DISPATCHES (Active Runs - CRITICAL OPERATIONAL DATA)
-- ============================================================

CREATE TABLE dispatches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispatch_number TEXT UNIQUE NOT NULL,
    truck_id UUID NOT NULL REFERENCES trucks(id),
    driver_id UUID REFERENCES drivers(id),
    origin_site_id UUID REFERENCES sites(id),
    destination_site_id UUID REFERENCES sites(id),
    status dispatch_status DEFAULT 'queued' NOT NULL,
    scheduled_start TIMESTAMPTZ,
    actual_start TIMESTAMPTZ,
    actual_end TIMESTAMPTZ,
    planned_route GEOMETRY(LINESTRING, 4326),
    current_lat DECIMAL(9,6),
    current_lng DECIMAL(9,6),
    last_position_update TIMESTAMPTZ,
    distance_km DECIMAL(8,2),
    estimated_duration_minutes INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id) NOT NULL,
    updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_dispatches_number ON dispatches(dispatch_number);
CREATE INDEX idx_dispatches_truck ON dispatches(truck_id);
CREATE INDEX idx_dispatches_driver ON dispatches(driver_id);
CREATE INDEX idx_dispatches_status ON dispatches(status);
CREATE INDEX idx_dispatches_created ON dispatches(created_at);
CREATE INDEX idx_dispatches_origin ON dispatches(origin_site_id);
CREATE INDEX idx_dispatches_destination ON dispatches(destination_site_id);
CREATE INDEX idx_dispatches_active ON dispatches(status) WHERE status IN ('queued', 'active');

-- ============================================================
-- RUN HISTORY (Archived Completed Runs)
-- ============================================================

CREATE TABLE run_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispatch_id UUID REFERENCES dispatches(id),
    truck_id UUID NOT NULL REFERENCES trucks(id),
    driver_id UUID REFERENCES drivers(id),
    origin_site_id UUID REFERENCES sites(id),
    destination_site_id UUID REFERENCES sites(id),
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    distance_km DECIMAL(8,2),
    avg_speed_kmh DECIMAL(5,2),
    max_speed_kmh DECIMAL(5,2),
    route_deviation_count INTEGER DEFAULT 0,
    speed_violation_count INTEGER DEFAULT 0,
    driver_rating DECIMAL(3,2),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_run_history_truck ON run_history(truck_id);
CREATE INDEX idx_run_history_driver ON run_history(driver_id);
CREATE INDEX idx_run_history_dates ON run_history(started_at, completed_at);
CREATE INDEX idx_run_history_origin ON run_history(origin_site_id);
CREATE INDEX idx_run_history_destination ON run_history(destination_site_id);

-- ============================================================
-- DISPATCH EVENTS (Audit Trail - Immutable)
-- ============================================================

CREATE TABLE dispatch_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispatch_id UUID NOT NULL REFERENCES dispatches(id),
    event_type event_type NOT NULL,
    description TEXT NOT NULL,
    metadata JSONB,
    occurred_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_dispatch_events_dispatch ON dispatch_events(dispatch_id);
CREATE INDEX idx_dispatch_events_type ON dispatch_events(event_type);
CREATE INDEX idx_dispatch_events_occurred ON dispatch_events(occurred_at);

-- ============================================================
-- NOTIFICATIONS (Alert History)
-- ============================================================

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_type notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    truck_id UUID REFERENCES trucks(id),
    driver_id UUID REFERENCES drivers(id),
    dispatch_id UUID REFERENCES dispatches(id),
    site_id UUID REFERENCES sites(id),
    is_read BOOLEAN DEFAULT false NOT NULL,
    is_acknowledged BOOLEAN DEFAULT false NOT NULL,
    acknowledged_by UUID REFERENCES profiles(id),
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_notifications_type ON notifications(notification_type);
CREATE INDEX idx_notifications_read ON notifications(is_read);
CREATE INDEX idx_notifications_truck ON notifications(truck_id);
CREATE INDEX idx_notifications_created ON notifications(created_at);

-- ============================================================
-- APP SETTINGS (Configuration Parameters)
-- ============================================================

CREATE TABLE app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT UNIQUE NOT NULL,
    setting_value JSONB NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    is_public BOOLEAN DEFAULT true NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_by UUID REFERENCES profiles(id)
);

CREATE INDEX idx_app_settings_key ON app_settings(setting_key);
CREATE INDEX idx_app_settings_category ON app_settings(category);

-- ============================================================
-- SHIFT LOGS (Employee Shift Tracking)
-- ============================================================

CREATE TABLE shift_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    shift_start TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    shift_end TIMESTAMPTZ,
    dispatches_handled INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_shift_logs_user ON shift_logs(user_id);
CREATE INDEX idx_shift_logs_dates ON shift_logs(shift_start, shift_end);

-- ============================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE geofences ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispatches ENABLE ROW LEVEL SECURITY;
ALTER TABLE run_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispatch_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE shift_logs ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can view own profile, admins view all
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id OR EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

CREATE POLICY "Admins can update all profiles" ON profiles
    FOR UPDATE USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

CREATE POLICY "Admins can insert profiles" ON profiles
    FOR INSERT WITH CHECK (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- Trucks: All authenticated users can read, operators+ can write
CREATE POLICY "Authenticated users can view trucks" ON trucks
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Operators can manage trucks" ON trucks
    FOR ALL USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'operator')
    ));

-- Drivers: Same as trucks
CREATE POLICY "Authenticated users can view drivers" ON drivers
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Operators can manage drivers" ON drivers
    FOR ALL USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'operator')
    ));

-- Sites: Same pattern
CREATE POLICY "Authenticated users can view sites" ON sites
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Operators can manage sites" ON sites
    FOR ALL USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'operator')
    ));

-- Geofences: Same pattern
CREATE POLICY "Authenticated users can view geofences" ON geofences
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Operators can manage geofences" ON geofences
    FOR ALL USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'operator')
    ));

-- Dispatches: Critical - all authenticated can read, operators+ can write
CREATE POLICY "Authenticated users can view dispatches" ON dispatches
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Operators can manage dispatches" ON dispatches
    FOR ALL USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'operator')
    ));

-- Run History: Read-only for most, system inserts
CREATE POLICY "Authenticated users can view run history" ON run_history
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can insert run history" ON run_history
    FOR INSERT WITH CHECK (true);

-- Dispatch Events: Read-only, system writes
CREATE POLICY "Authenticated users can view events" ON dispatch_events
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can insert events" ON dispatch_events
    FOR INSERT WITH CHECK (true);

-- Notifications: All can read, system writes, users can mark as read
CREATE POLICY "Authenticated users can view notifications" ON notifications
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "System can insert notifications" ON notifications
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (true);

-- App Settings: Public settings readable by all, admins can write
CREATE POLICY "Public settings readable by all" ON app_settings
    FOR SELECT USING (is_public = true OR EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('admin', 'operator')
    ));

CREATE POLICY "Admins can manage settings" ON app_settings
    FOR ALL USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- Shift Logs: Users can view own, admins view all
CREATE POLICY "Users can view own shifts" ON shift_logs
    FOR SELECT USING (user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

CREATE POLICY "System can insert shift logs" ON shift_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can end own shifts" ON shift_logs
    FOR UPDATE USING (user_id = auth.uid() OR EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.updated_by = auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tables with updated_at
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trucks_updated_at BEFORE UPDATE ON trucks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drivers_updated_at BEFORE UPDATE ON drivers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_geofences_updated_at BEFORE UPDATE ON geofences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dispatches_updated_at BEFORE UPDATE ON dispatches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_app_settings_updated_at BEFORE UPDATE ON app_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate dispatch number
CREATE OR REPLACE FUNCTION generate_dispatch_number()
RETURNS TRIGGER AS $$
DECLARE
    new_number TEXT;
BEGIN
    SELECT 'DISP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(COUNT(*)::TEXT, 4, '0')
    INTO new_number
    FROM dispatches
    WHERE DATE(created_at) = DATE(NOW());
    
    NEW.dispatch_number = COALESCE(new_number, 'DISP-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-0001');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_dispatch_number_before_insert
    BEFORE INSERT ON dispatches
    FOR EACH ROW
    WHEN (NEW.dispatch_number IS NULL)
    EXECUTE FUNCTION generate_dispatch_number();

-- Function to archive completed dispatches to run_history
CREATE OR REPLACE FUNCTION archive_completed_dispatch()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        INSERT INTO run_history (
            dispatch_id, truck_id, driver_id, origin_site_id, destination_site_id,
            started_at, completed_at, notes, created_at
        )
        VALUES (
            NEW.id, NEW.truck_id, NEW.driver_id, NEW.origin_site_id, NEW.destination_site_id,
            NEW.actual_start, NEW.actual_end, NEW.notes, NOW()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER archive_dispatch_on_completion
    AFTER UPDATE ON dispatches
    FOR EACH ROW
    WHEN (NEW.status = 'completed' AND OLD.status != 'completed')
    EXECUTE FUNCTION archive_completed_dispatch();

-- Function to update driver rating after run completion
CREATE OR REPLACE FUNCTION update_driver_rating()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.driver_rating IS NOT NULL THEN
        UPDATE drivers
        SET rating_avg = (
                SELECT AVG(driver_rating) FROM run_history WHERE driver_id = NEW.driver_id
            ),
            total_runs = (
                SELECT COUNT(*) FROM run_history WHERE driver_id = NEW.driver_id
            ),
            updated_at = NOW()
        WHERE id = NEW.driver_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_driver_rating_on_run
    AFTER INSERT ON run_history
    FOR EACH ROW
    WHEN (NEW.driver_rating IS NOT NULL)
    EXECUTE FUNCTION update_driver_rating();

-- ============================================================
-- INITIAL DATA (Default Settings)
-- ============================================================

INSERT INTO app_settings (setting_key, setting_value, description, category, is_public) VALUES
('speed_threshold', '{"value": 90, "unit": "kmh"}', 'Maximum allowed speed before alert', 'monitoring', true),
('off_route_tolerance', '{"value": 500, "unit": "meters"}', 'Distance tolerance for route deviation', 'monitoring', true),
('polling_interval', '{"value": 30, "unit": "seconds"}', 'Wialon polling frequency', 'connection', true),
('session_timeout', '{"value": 480, "unit": "minutes"}', 'User session timeout', 'authentication', false),
('default_map_zoom', '{"value": 12}', 'Default map zoom level', 'map', true),
('factory_coords', '{"lat": 35.2089, "lng": 36.7544}', 'Factory (Amouda) coordinates', 'locations', true);

-- ============================================================
-- REALTIME SUBSCRIPTIONS (for live updates)
-- ============================================================

-- Enable realtime for critical tables
ALTER PUBLICATION supabase_realtime ADD TABLE dispatches;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE trucks;

-- ============================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================

COMMENT ON TABLE profiles IS 'User profiles extending Supabase auth';
COMMENT ON TABLE trucks IS 'Fleet vehicle reference data';
COMMENT ON TABLE drivers IS 'Driver information and ratings';
COMMENT ON TABLE sites IS 'Construction sites, clients, and locations';
COMMENT ON TABLE geofences IS 'Geographic monitoring boundaries';
COMMENT ON TABLE dispatches IS 'Active operational runs (critical state)';
COMMENT ON TABLE run_history IS 'Archived completed runs for analytics';
COMMENT ON TABLE dispatch_events IS 'Immutable audit trail of all operations';
COMMENT ON TABLE notifications IS 'System alerts and notifications';
COMMENT ON TABLE app_settings IS 'Application configuration parameters';
COMMENT ON TABLE shift_logs IS 'Employee shift tracking';
