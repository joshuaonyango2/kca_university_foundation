-- backend/schema.sql
-- KCA Foundation Database Schema

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS TABLE
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role VARCHAR(20) NOT NULL CHECK (role IN ('donor', 'admin', 'staff', 'finance')),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    organization VARCHAR(255),
    is_corporate BOOLEAN DEFAULT FALSE,
    is_anonymous BOOLEAN DEFAULT FALSE,
    profile_image_url TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended'))
);

-- CAMPAIGNS TABLE
CREATE TABLE campaigns (
    campaign_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL CHECK (category IN ('scholarship', 'endowment', 'infrastructure', 'research', 'general')),
    goal_amount DECIMAL(15, 2) NOT NULL,
    current_amount DECIMAL(15, 2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'KES',
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft', 'active', 'paused', 'completed', 'archived')),
    featured BOOLEAN DEFAULT FALSE,
    image_url TEXT,
    video_url TEXT,
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_campaigns_category ON campaigns(category);
CREATE INDEX idx_campaigns_status ON campaigns(status);

-- DONATIONS TABLE
CREATE TABLE donations (
    donation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KES',
    payment_method VARCHAR(50) NOT NULL CHECK (payment_method IN ('mpesa', 'card', 'bank_transfer', 'paypal')),
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_frequency VARCHAR(20) CHECK (recurrence_frequency IN ('monthly', 'quarterly', 'yearly')),
    is_anonymous BOOLEAN DEFAULT FALSE,
    donor_name VARCHAR(255),
    donor_email VARCHAR(255),
    donor_phone VARCHAR(20),
    donation_status VARCHAR(20) DEFAULT 'pending' CHECK (donation_status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
    payment_fee DECIMAL(10, 2) DEFAULT 0,
    net_amount DECIMAL(15, 2),
    dedication_message TEXT,
    transaction_reference VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_donations_user ON donations(user_id);
CREATE INDEX idx_donations_campaign ON donations(campaign_id);
CREATE INDEX idx_donations_status ON donations(donation_status);
CREATE INDEX idx_donations_created ON donations(created_at DESC);

-- PAYMENTS TABLE
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donation_id UUID REFERENCES donations(donation_id),
    provider VARCHAR(50) NOT NULL,
    provider_reference VARCHAR(255),
    provider_response JSON,
    confirmation_status VARCHAR(20) DEFAULT 'pending' CHECK (confirmation_status IN ('pending', 'confirmed', 'failed', 'reversed')),
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KES',
    payment_phone VARCHAR(20),
    payment_email VARCHAR(255),
    reconciled BOOLEAN DEFAULT FALSE,
    reconciled_at TIMESTAMP,
    reconciled_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_payments_donation ON payments(donation_id);
CREATE INDEX idx_payments_status ON payments(confirmation_status);

-- RECEIPTS TABLE
CREATE TABLE receipts (
    receipt_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donation_id UUID REFERENCES donations(donation_id) UNIQUE,
    receipt_number VARCHAR(50) UNIQUE NOT NULL,
    pdf_url TEXT,
    issued_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    sent_via_email BOOLEAN DEFAULT FALSE,
    email_sent_at TIMESTAMP,
    tax_deductible BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_receipts_donation ON receipts(donation_id);

-- RECURRING_SCHEDULES TABLE
CREATE TABLE recurring_schedules (
    schedule_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    campaign_id UUID REFERENCES campaigns(campaign_id),
    original_donation_id UUID REFERENCES donations(donation_id),
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KES',
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('monthly', 'quarterly', 'yearly')),
    payment_method VARCHAR(50) NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled', 'completed')),
    next_payment_date DATE,
    last_payment_date DATE,
    start_date DATE NOT NULL,
    total_payments_made INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NOTIFICATIONS TABLE
CREATE TABLE notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    action_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user ON notifications(user_id);

-- TRIGGERS
CREATE OR REPLACE FUNCTION update_campaign_amount()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.donation_status = 'completed' AND OLD.donation_status != 'completed' THEN
        UPDATE campaigns 
        SET current_amount = current_amount + NEW.amount
        WHERE campaign_id = NEW.campaign_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_campaign_amount
AFTER UPDATE ON donations
FOR EACH ROW
EXECUTE FUNCTION update_campaign_amount();

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_campaigns_updated_at BEFORE UPDATE ON campaigns
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_donations_updated_at BEFORE UPDATE ON donations
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- SAMPLE DATA
INSERT INTO users (role, email, phone_number, password_hash, first_name, last_name, email_verified, phone_verified)
VALUES ('admin', 'admin@kca.ac.ke', '+254700000000', '$2b$10$YourHashedPasswordHere', 'System', 'Admin', TRUE, TRUE);

INSERT INTO campaigns (title, slug, description, category, goal_amount, status, featured)
VALUES 
('Student Scholarship Fund 2024', 'scholarship-fund-2024', 'Support deserving students with full scholarships', 'scholarship', 5000000.00, 'active', TRUE),
('University Endowment Fund', 'endowment-fund', 'Build a sustainable endowment for long-term impact', 'endowment', 50000000.00, 'active', TRUE),
('New Library Infrastructure', 'library-infrastructure', 'Construct a modern library facility', 'infrastructure', 20000000.00, 'active', FALSE),
('Research & Innovation Grant', 'research-innovation', 'Fund cutting-edge research projects', 'research', 10000000.00, 'active', FALSE);