-- Ticket System Database Schema
-- This schema supports a single-guild ticket system with configurable categories

-- ============================================================================
-- TICKETS TABLE
-- ============================================================================
-- Stores the main ticket information and state
CREATE TABLE IF NOT EXISTS tickets (
    -- Primary identifier
    ticket_id SERIAL PRIMARY KEY,
    
    -- Discord references
    channel_id VARCHAR(19) UNIQUE NOT NULL,  -- Discord channel ID (snowflake)
    creator_id VARCHAR(19) NOT NULL,          -- User who created the ticket
    
    -- Ticket metadata
    category_key VARCHAR(50) NOT NULL,        -- References config category (e.g., 'technical', 'support')
    ticket_number INTEGER NOT NULL,           -- Sequential number per category
    
    -- State tracking
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    closed_at TIMESTAMP WITH TIME ZONE,
    
    -- Archive information
    archived BOOLEAN NOT NULL DEFAULT false,
    archive_path TEXT,                        -- Path to archived file if archived
    archive_format VARCHAR(10),               -- 'json', 'txt', or 'html'
    
    -- Additional metadata
    close_reason TEXT,                        -- Optional reason for closing
    closed_by VARCHAR(19),                    -- User ID who closed the ticket
    
    -- Indexes for common queries
    CONSTRAINT unique_category_number UNIQUE (category_key, ticket_number)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_tickets_channel ON tickets(channel_id);
CREATE INDEX IF NOT EXISTS idx_tickets_creator ON tickets(creator_id);
CREATE INDEX IF NOT EXISTS idx_tickets_category ON tickets(category_key);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);
CREATE INDEX IF NOT EXISTS idx_tickets_created_at ON tickets(created_at DESC);

-- ============================================================================
-- TICKET_PARTICIPANTS TABLE
-- ============================================================================
-- Tracks users who have been added to tickets beyond the creator and staff roles
CREATE TABLE IF NOT EXISTS ticket_participants (
    id SERIAL PRIMARY KEY,
    
    -- Foreign key to ticket
    ticket_id INTEGER NOT NULL REFERENCES tickets(ticket_id) ON DELETE CASCADE,
    
    -- User information
    user_id VARCHAR(19) NOT NULL,             -- Discord user ID
    
    -- Metadata
    added_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    added_by VARCHAR(19) NOT NULL,            -- User ID who added this participant
    
    -- Ensure no duplicate participants per ticket
    CONSTRAINT unique_ticket_participant UNIQUE (ticket_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_participants_ticket ON ticket_participants(ticket_id);
CREATE INDEX IF NOT EXISTS idx_participants_user ON ticket_participants(user_id);

-- ============================================================================
-- TICKET_MESSAGES TABLE (Optional - for archiving)
-- ============================================================================
-- Stores ticket messages for archiving purposes
-- Only populated when archiving is enabled
CREATE TABLE IF NOT EXISTS ticket_messages (
    id SERIAL PRIMARY KEY,
    
    -- Foreign key to ticket
    ticket_id INTEGER NOT NULL REFERENCES tickets(ticket_id) ON DELETE CASCADE,
    
    -- Message information
    message_id VARCHAR(19) NOT NULL,          -- Discord message ID
    author_id VARCHAR(19) NOT NULL,           -- Message author
    author_username VARCHAR(255) NOT NULL,    -- Author's username at time of message
    
    -- Content
    content TEXT,                             -- Message text content
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    edited_at TIMESTAMP WITH TIME ZONE,
    
    -- Attachments (stored as JSON array)
    attachments JSONB DEFAULT '[]'::jsonb,    -- Array of attachment URLs/info
    
    -- Embeds (stored as JSON)
    embeds JSONB DEFAULT '[]'::jsonb,         -- Array of embed data
    
    CONSTRAINT unique_ticket_message UNIQUE (ticket_id, message_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_ticket ON ticket_messages(ticket_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON ticket_messages(created_at);

-- ============================================================================
-- TICKET_PANELS TABLE
-- ============================================================================
-- Stores active ticket panel messages for recreation after bot restart
CREATE TABLE IF NOT EXISTS ticket_panels (
    id SERIAL PRIMARY KEY,
    
    -- Discord references
    channel_id VARCHAR(19) NOT NULL,          -- Channel where panel is posted
    message_id VARCHAR(19) UNIQUE NOT NULL,   -- Panel message ID
    
    -- Panel configuration
    panel_config JSONB NOT NULL,              -- Stores button configs and categories shown
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_panels_message ON ticket_panels(message_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to get next ticket number for a category
CREATE OR REPLACE FUNCTION get_next_ticket_number(p_category_key VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    v_next_number INTEGER;
BEGIN
    SELECT COALESCE(MAX(ticket_number), 0) + 1
    INTO v_next_number
    FROM tickets
    WHERE category_key = p_category_key;
    
    RETURN v_next_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SAMPLE QUERIES
-- ============================================================================

-- Get all open tickets for a user
-- SELECT * FROM tickets WHERE creator_id = 'USER_ID' AND status = 'open';

-- Get all tickets in a category
-- SELECT * FROM tickets WHERE category_key = 'technical' ORDER BY created_at DESC;

-- Get ticket with participants
-- SELECT t.*, array_agg(tp.user_id) as participants
-- FROM tickets t
-- LEFT JOIN ticket_participants tp ON t.ticket_id = tp.ticket_id
-- WHERE t.ticket_id = 1
-- GROUP BY t.ticket_id;

-- Get ticket message count
-- SELECT ticket_id, COUNT(*) as message_count
-- FROM ticket_messages
-- GROUP BY ticket_id;

-- Archive statistics
-- SELECT 
--     category_key,
--     COUNT(*) FILTER (WHERE archived = true) as archived_count,
--     COUNT(*) FILTER (WHERE status = 'closed' AND archived = false) as unarchived_closed
-- FROM tickets
-- GROUP BY category_key;