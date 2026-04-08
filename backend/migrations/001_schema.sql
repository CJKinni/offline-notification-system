-- Hermes database schema
-- sqlx migrations runner applies this on startup

CREATE TABLE IF NOT EXISTS users (
    id          TEXT PRIMARY KEY,
    email       TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    subscription_tier TEXT NOT NULL DEFAULT 'free',
    subscription_expires_at INTEGER,
    active_profile_id TEXT
);

CREATE TABLE IF NOT EXISTS profiles (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    name        TEXT NOT NULL,
    description TEXT,
    is_active   INTEGER NOT NULL DEFAULT 1,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS agents (
    id                  TEXT PRIMARY KEY,
    user_id             TEXT NOT NULL,
    profile_id          TEXT,
    name                TEXT NOT NULL,
    description         TEXT,
    provider            TEXT NOT NULL DEFAULT 'claude',
    model               TEXT NOT NULL,
    system_prompt       TEXT,
    temperature         REAL NOT NULL DEFAULT 0.7,
    max_tokens          INTEGER NOT NULL DEFAULT 4096,
    fallback_provider   TEXT,
    fallback_model      TEXT,
    is_active           INTEGER NOT NULL DEFAULT 1,
    created_at          INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at          INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE SET NULL
);

-- SOUL.md equivalent: per-agent personality configuration
CREATE TABLE IF NOT EXISTS soul_configs (
    id              TEXT PRIMARY KEY,
    agent_id        TEXT NOT NULL UNIQUE,
    persona         TEXT NOT NULL DEFAULT '',
    tone            TEXT NOT NULL DEFAULT 'helpful',
    values_json     TEXT NOT NULL DEFAULT '[]',
    restrictions_json TEXT NOT NULL DEFAULT '[]',
    memory_enabled  INTEGER NOT NULL DEFAULT 1,
    updated_at      INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
);

-- SKILL.md equivalent: reusable capability docs injected into system prompt
CREATE TABLE IF NOT EXISTS skills (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    name        TEXT NOT NULL,
    description TEXT,
    content_md  TEXT NOT NULL,
    category    TEXT NOT NULL DEFAULT 'general',
    tags_json   TEXT NOT NULL DEFAULT '[]',
    usage_count INTEGER NOT NULL DEFAULT 0,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS agent_skills (
    agent_id    TEXT NOT NULL,
    skill_id    TEXT NOT NULL,
    attached_at INTEGER NOT NULL DEFAULT (unixepoch()),
    PRIMARY KEY (agent_id, skill_id),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(id) ON DELETE CASCADE
);

-- Markdown-based agent memory (openclaw-style)
CREATE TABLE IF NOT EXISTS memories (
    id              TEXT PRIMARY KEY,
    agent_id        TEXT NOT NULL UNIQUE,
    content_md      TEXT NOT NULL DEFAULT '',
    importance      REAL NOT NULL DEFAULT 0.5,
    created_at      INTEGER NOT NULL DEFAULT (unixepoch()),
    last_accessed_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS conversations (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    agent_id    TEXT NOT NULL,
    profile_id  TEXT,
    title       TEXT,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS messages (
    id              TEXT PRIMARY KEY,
    conversation_id TEXT NOT NULL,
    role            TEXT NOT NULL,
    content         TEXT NOT NULL,
    provider        TEXT,
    model           TEXT,
    tokens_used     INTEGER,
    used_fallback   INTEGER NOT NULL DEFAULT 0,
    created_at      INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS flows (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    profile_id  TEXT,
    name        TEXT NOT NULL,
    description TEXT,
    nodes_json  TEXT NOT NULL DEFAULT '[]',
    edges_json  TEXT NOT NULL DEFAULT '[]',
    is_active   INTEGER NOT NULL DEFAULT 1,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS flow_runs (
    id              TEXT PRIMARY KEY,
    flow_id         TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending',
    input_json      TEXT,
    output_json     TEXT,
    error           TEXT,
    started_at      INTEGER,
    completed_at    INTEGER,
    duration_ms     INTEGER,
    FOREIGN KEY (flow_id) REFERENCES flows(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS crons (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    profile_id  TEXT,
    name        TEXT NOT NULL,
    description TEXT,
    schedule    TEXT NOT NULL,
    flow_id     TEXT,
    agent_id    TEXT,
    prompt      TEXT,
    is_active   INTEGER NOT NULL DEFAULT 1,
    last_run_at INTEGER,
    run_count   INTEGER NOT NULL DEFAULT 0,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS integrations (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL,
    profile_id      TEXT,
    type            TEXT NOT NULL,
    name            TEXT NOT NULL,
    config_json     TEXT NOT NULL DEFAULT '{}',
    credentials_enc TEXT NOT NULL DEFAULT '{}',
    is_active       INTEGER NOT NULL DEFAULT 1,
    last_synced_at  INTEGER,
    created_at      INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS api_keys (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    provider    TEXT NOT NULL,
    key_enc     TEXT NOT NULL,
    created_at  INTEGER NOT NULL DEFAULT (unixepoch()),
    UNIQUE (user_id, provider),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_agents_user ON agents(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_convo ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_crons_user ON crons(user_id);
CREATE INDEX IF NOT EXISTS idx_flows_user ON flows(user_id);
