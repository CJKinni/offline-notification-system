use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;
use crate::{utils::{auth::AuthUser, errors::{AppError, AppResult}}, AppState};

#[derive(Deserialize)]
pub struct SkillRequest {
    pub name: String,
    pub description: Option<String>,
    pub content_md: String,
    pub category: Option<String>,
    pub tags: Option<Vec<String>>,
}

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!(
        "SELECT id, name, description, category, tags_json, usage_count FROM skills WHERE user_id = ? ORDER BY usage_count DESC",
        auth.0.sub
    ).fetch_all(&s.db).await?;
    let list: Vec<_> = rows.iter().map(|r| json!({
        "id": r.id, "name": r.name, "description": r.description,
        "category": r.category, "usage_count": r.usage_count
    })).collect();
    Ok(Json(json!({ "skills": list })))
}

pub async fn library(_auth: AuthUser, State(_s): State<AppState>) -> Json<serde_json::Value> {
    // Curated seed skills shipped with the backend
    Json(json!({ "skills": [
        { "name": "Web Research", "category": "research", "description": "Research topics on the web and summarize findings", "content_md": "When asked to research a topic:\n1. Break it into key questions\n2. Search for authoritative sources\n3. Cross-reference findings\n4. Summarize concisely with citations" },
        { "name": "Code Review", "category": "engineering", "description": "Review code for bugs, security, and style", "content_md": "When reviewing code:\n1. Check for correctness and edge cases\n2. Look for security vulnerabilities (injection, auth issues)\n3. Suggest performance improvements\n4. Comment on code style and readability" },
        { "name": "Email Drafter", "category": "writing", "description": "Draft professional emails", "content_md": "When drafting emails:\n- Subject line: clear and specific\n- Opening: context in one sentence\n- Body: concise, one ask per email\n- Closing: clear call-to-action\n- Tone: professional but warm" },
        { "name": "Daily Planner", "category": "productivity", "description": "Plan and prioritize daily tasks", "content_md": "When planning a day:\n1. List all tasks\n2. Prioritize by impact × urgency\n3. Time-block focused work\n4. Include breaks\n5. End with a review checklist" },
        { "name": "Data Analyst", "category": "data", "description": "Analyze data and draw insights", "content_md": "When analyzing data:\n1. Understand the question first\n2. Check data quality and outliers\n3. Apply appropriate statistical methods\n4. Visualize key findings\n5. State conclusions with confidence levels" }
    ]}))
}

pub async fn get(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    let r = sqlx::query!(
        "SELECT * FROM skills WHERE id = ? AND user_id = ?", id, auth.0.sub
    ).fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Skill not found".into()))?;
    Ok(Json(json!({ "id": r.id, "name": r.name, "content_md": r.content_md, "category": r.category })))
}

pub async fn create(auth: AuthUser, State(s): State<AppState>, Json(body): Json<SkillRequest>) -> AppResult<Json<serde_json::Value>> {
    let id = Uuid::new_v4().to_string();
    let tags = serde_json::to_string(&body.tags.unwrap_or_default()).unwrap();
    let cat = body.category.unwrap_or_else(|| "general".into());
    sqlx::query!(
        "INSERT INTO skills (id, user_id, name, description, content_md, category, tags_json) VALUES (?,?,?,?,?,?,?)",
        id, auth.0.sub, body.name, body.description, body.content_md, cat, tags
    ).execute(&s.db).await?;
    Ok(Json(json!({ "id": id })))
}

pub async fn update(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>, Json(body): Json<SkillRequest>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!(
        "UPDATE skills SET name=?,description=?,content_md=?,updated_at=unixepoch() WHERE id=? AND user_id=?",
        body.name, body.description, body.content_md, id, auth.0.sub
    ).execute(&s.db).await?;
    Ok(Json(json!({ "updated": true })))
}

pub async fn delete(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("DELETE FROM skills WHERE id=? AND user_id=?", id, auth.0.sub).execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}
