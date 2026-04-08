use axum::{
    extract::{Path, State},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;
use crate::{
    agents::types::Provider,
    utils::{auth::AuthUser, errors::{AppError, AppResult}},
    AppState,
};

#[derive(Deserialize)]
pub struct CreateAgentRequest {
    pub name: String,
    pub description: Option<String>,
    pub provider: String,
    pub model: String,
    pub system_prompt: Option<String>,
    pub temperature: Option<f64>,
    pub max_tokens: Option<i64>,
    pub fallback_provider: Option<String>,
    pub fallback_model: Option<String>,
}

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!(
        "SELECT id, name, description, provider, model, is_active, created_at
         FROM agents WHERE user_id = ? AND is_active = 1 ORDER BY created_at DESC",
        auth.0.sub
    )
    .fetch_all(&s.db).await?;
    let agents: Vec<_> = rows.iter().map(|r| json!({
        "id": r.id, "name": r.name, "description": r.description,
        "provider": r.provider, "model": r.model, "created_at": r.created_at
    })).collect();
    Ok(Json(json!({ "agents": agents })))
}

pub async fn create(
    auth: AuthUser,
    State(s): State<AppState>,
    Json(body): Json<CreateAgentRequest>,
) -> AppResult<Json<serde_json::Value>> {
    // Validate provider
    body.provider.parse::<Provider>()
        .map_err(|_| AppError::BadRequest(format!("Unknown provider: {}", body.provider)))?;

    let id = Uuid::new_v4().to_string();
    let temp = body.temperature.unwrap_or(0.7);
    let max_tok = body.max_tokens.unwrap_or(4096);
    sqlx::query!(
        "INSERT INTO agents (id, user_id, name, description, provider, model, system_prompt,
         temperature, max_tokens, fallback_provider, fallback_model)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        id, auth.0.sub, body.name, body.description, body.provider, body.model,
        body.system_prompt, temp, max_tok, body.fallback_provider, body.fallback_model
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "id": id, "name": body.name })))
}

pub async fn get(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let r = sqlx::query!(
        "SELECT * FROM agents WHERE id = ? AND user_id = ?",
        id, auth.0.sub
    )
    .fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Agent not found".into()))?;
    Ok(Json(json!({
        "id": r.id, "name": r.name, "description": r.description,
        "provider": r.provider, "model": r.model, "system_prompt": r.system_prompt,
        "temperature": r.temperature, "max_tokens": r.max_tokens,
        "fallback_provider": r.fallback_provider, "fallback_model": r.fallback_model,
        "created_at": r.created_at
    })))
}

pub async fn update(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<CreateAgentRequest>,
) -> AppResult<Json<serde_json::Value>> {
    let temp = body.temperature.unwrap_or(0.7);
    let max_tok = body.max_tokens.unwrap_or(4096);
    let rows = sqlx::query!(
        "UPDATE agents SET name=?, description=?, provider=?, model=?, system_prompt=?,
         temperature=?, max_tokens=?, fallback_provider=?, fallback_model=?,
         updated_at=unixepoch()
         WHERE id=? AND user_id=?",
        body.name, body.description, body.provider, body.model, body.system_prompt,
        temp, max_tok, body.fallback_provider, body.fallback_model, id, auth.0.sub
    )
    .execute(&s.db).await?;
    if rows.rows_affected() == 0 {
        return Err(AppError::NotFound("Agent not found".into()));
    }
    Ok(Json(json!({ "id": id, "updated": true })))
}

pub async fn delete(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!(
        "UPDATE agents SET is_active=0 WHERE id=? AND user_id=?",
        id, auth.0.sub
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}

pub async fn get_soul(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let soul = sqlx::query!(
        "SELECT sc.* FROM soul_configs sc
         JOIN agents a ON a.id = sc.agent_id
         WHERE sc.agent_id = ? AND a.user_id = ?",
        id, auth.0.sub
    )
    .fetch_optional(&s.db).await?;
    match soul {
        Some(s) => Ok(Json(json!({
            "persona": s.persona, "tone": s.tone,
            "values": serde_json::from_str::<serde_json::Value>(&s.values_json).unwrap_or(json!([])),
            "restrictions": serde_json::from_str::<serde_json::Value>(&s.restrictions_json).unwrap_or(json!([])),
            "memory_enabled": s.memory_enabled
        }))),
        None => Ok(Json(json!({ "persona": "", "tone": "helpful", "values": [], "restrictions": [] }))),
    }
}

#[derive(Deserialize)]
pub struct SoulRequest {
    pub persona: Option<String>,
    pub tone: Option<String>,
    pub values: Option<Vec<String>>,
    pub restrictions: Option<Vec<String>>,
    pub memory_enabled: Option<bool>,
}

pub async fn upsert_soul(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<SoulRequest>,
) -> AppResult<Json<serde_json::Value>> {
    let soul_id = Uuid::new_v4().to_string();
    let persona = body.persona.unwrap_or_default();
    let tone = body.tone.unwrap_or_else(|| "helpful".into());
    let values = serde_json::to_string(&body.values.unwrap_or_default()).unwrap();
    let restrictions = serde_json::to_string(&body.restrictions.unwrap_or_default()).unwrap();
    let mem = body.memory_enabled.unwrap_or(true) as i64;
    sqlx::query!(
        "INSERT INTO soul_configs (id, agent_id, persona, tone, values_json, restrictions_json, memory_enabled)
         VALUES (?,?,?,?,?,?,?)
         ON CONFLICT(agent_id) DO UPDATE SET
         persona=excluded.persona, tone=excluded.tone, values_json=excluded.values_json,
         restrictions_json=excluded.restrictions_json, memory_enabled=excluded.memory_enabled,
         updated_at=unixepoch()",
        soul_id, id, persona, tone, values, restrictions, mem
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "updated": true })))
}

pub async fn get_memory(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let mem = sqlx::query!("SELECT content_md FROM memories WHERE agent_id = ?", id)
        .fetch_optional(&s.db).await?;
    Ok(Json(json!({ "content": mem.map(|m| m.content_md).unwrap_or_default() })))
}

pub async fn set_memory(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<serde_json::Value>,
) -> AppResult<Json<serde_json::Value>> {
    let content = body["content"].as_str().unwrap_or("").to_string();
    let mem_id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO memories (id, agent_id, content_md) VALUES (?,?,?)
         ON CONFLICT(agent_id) DO UPDATE SET content_md=excluded.content_md, last_accessed_at=unixepoch()",
        mem_id, id, content
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "updated": true })))
}

pub async fn append_memory(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<serde_json::Value>,
) -> AppResult<Json<serde_json::Value>> {
    let chunk = body["chunk"].as_str().unwrap_or("");
    let mem_id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO memories (id, agent_id, content_md) VALUES (?,?,?)
         ON CONFLICT(agent_id) DO UPDATE SET
         content_md = content_md || '\n' || excluded.content_md,
         last_accessed_at = unixepoch()",
        mem_id, id, chunk
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "appended": true })))
}

pub async fn list_skills(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let skills = sqlx::query!(
        "SELECT sk.id, sk.name, sk.description, sk.category
         FROM skills sk JOIN agent_skills ags ON ags.skill_id = sk.id
         WHERE ags.agent_id = ?",
        id
    )
    .fetch_all(&s.db).await?;
    let list: Vec<_> = skills.iter().map(|r| json!({
        "id": r.id, "name": r.name, "description": r.description, "category": r.category
    })).collect();
    Ok(Json(json!({ "skills": list })))
}

pub async fn attach_skill(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
    Json(body): Json<serde_json::Value>,
) -> AppResult<Json<serde_json::Value>> {
    let skill_id = body["skill_id"].as_str()
        .ok_or_else(|| AppError::BadRequest("Missing skill_id".into()))?;
    sqlx::query!(
        "INSERT OR IGNORE INTO agent_skills (agent_id, skill_id) VALUES (?,?)",
        id, skill_id
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "attached": true })))
}

pub async fn detach_skill(
    auth: AuthUser,
    State(s): State<AppState>,
    Path((agent_id, skill_id)): Path<(String, String)>,
) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!(
        "DELETE FROM agent_skills WHERE agent_id = ? AND skill_id = ?",
        agent_id, skill_id
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "detached": true })))
}
