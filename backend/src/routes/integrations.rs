use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;
use crate::{
    integrations::execute_integration,
    utils::{auth::AuthUser, crypto::{decrypt, encrypt}, errors::{AppError, AppResult}},
    AppState,
};

#[derive(Deserialize)]
pub struct IntegrationRequest {
    #[serde(rename = "type")]
    pub integration_type: String,
    pub name: String,
    pub config: serde_json::Value,
    pub credentials: serde_json::Value,
}

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!(
        "SELECT id, type, name, is_active, last_synced_at FROM integrations WHERE user_id = ?",
        auth.0.sub
    ).fetch_all(&s.db).await?;
    let list: Vec<_> = rows.iter().map(|r| json!({
        "id": r.id, "type": r.r#type, "name": r.name,
        "is_active": r.is_active, "last_synced_at": r.last_synced_at
    })).collect();
    Ok(Json(json!({ "integrations": list })))
}

pub async fn get(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    let r = sqlx::query!(
        "SELECT id, type, name, config_json, is_active FROM integrations WHERE id = ? AND user_id = ?",
        id, auth.0.sub
    ).fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Integration not found".into()))?;
    let config: serde_json::Value = serde_json::from_str(&r.config_json).unwrap_or(json!({}));
    Ok(Json(json!({ "id": r.id, "type": r.r#type, "name": r.name, "config": config })))
}

pub async fn create(auth: AuthUser, State(s): State<AppState>, Json(body): Json<IntegrationRequest>) -> AppResult<Json<serde_json::Value>> {
    let id = Uuid::new_v4().to_string();
    let config = serde_json::to_string(&body.config).unwrap();
    let creds_plain = serde_json::to_string(&body.credentials).unwrap();
    let creds_enc = encrypt(&creds_plain, &s.config.encryption_key)
        .map_err(|e| AppError::Internal(e))?;
    sqlx::query!(
        "INSERT INTO integrations (id, user_id, type, name, config_json, credentials_enc) VALUES (?,?,?,?,?,?)",
        id, auth.0.sub, body.integration_type, body.name, config, creds_enc
    ).execute(&s.db).await?;
    Ok(Json(json!({ "id": id })))
}

pub async fn update(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>, Json(body): Json<IntegrationRequest>) -> AppResult<Json<serde_json::Value>> {
    let config = serde_json::to_string(&body.config).unwrap();
    let creds_plain = serde_json::to_string(&body.credentials).unwrap();
    let creds_enc = encrypt(&creds_plain, &s.config.encryption_key)
        .map_err(|e| AppError::Internal(e))?;
    sqlx::query!(
        "UPDATE integrations SET name=?,config_json=?,credentials_enc=? WHERE id=? AND user_id=?",
        body.name, config, creds_enc, id, auth.0.sub
    ).execute(&s.db).await?;
    Ok(Json(json!({ "updated": true })))
}

pub async fn delete(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!("DELETE FROM integrations WHERE id=? AND user_id=?", id, auth.0.sub).execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}

pub async fn test(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>) -> AppResult<Json<serde_json::Value>> {
    let row = sqlx::query!(
        "SELECT type, config_json, credentials_enc FROM integrations WHERE id=? AND user_id=?",
        id, auth.0.sub
    ).fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Integration not found".into()))?;

    let creds_plain = decrypt(&row.credentials_enc, &s.config.encryption_key)
        .map_err(|e| AppError::Internal(e))?;
    let credentials: serde_json::Value = serde_json::from_str(&creds_plain).unwrap_or(json!({}));
    let config: serde_json::Value = serde_json::from_str(&row.config_json).unwrap_or(json!({}));

    let ok = match row.r#type.as_str() {
        "gmail" => crate::integrations::gmail::GmailIntegration.test(&config, &credentials).await?,
        "calendar" => crate::integrations::calendar::CalendarIntegration.test(&config, &credentials).await?,
        "slack" => crate::integrations::slack::SlackIntegration.test(&config, &credentials).await?,
        "webhook" => crate::integrations::webhook::WebhookIntegration.test(&config, &credentials).await?,
        "rss" => crate::integrations::rss::RssIntegration.test(&config, &credentials).await?,
        _ => false,
    };

    sqlx::query!("UPDATE integrations SET last_synced_at=unixepoch() WHERE id=?", id).execute(&s.db).await?;
    Ok(Json(json!({ "success": ok })))
}

#[derive(Deserialize)]
pub struct ExecuteRequest {
    pub action: String,
    pub params: serde_json::Value,
}

pub async fn execute(auth: AuthUser, State(s): State<AppState>, Path(id): Path<String>, Json(body): Json<ExecuteRequest>) -> AppResult<Json<serde_json::Value>> {
    let row = sqlx::query!(
        "SELECT type, config_json, credentials_enc FROM integrations WHERE id=? AND user_id=?",
        id, auth.0.sub
    ).fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Integration not found".into()))?;

    let creds_plain = decrypt(&row.credentials_enc, &s.config.encryption_key)
        .map_err(|e| AppError::Internal(e))?;
    let credentials: serde_json::Value = serde_json::from_str(&creds_plain).unwrap_or(json!({}));
    let config: serde_json::Value = serde_json::from_str(&row.config_json).unwrap_or(json!({}));

    let result = execute_integration(&row.r#type, &body.action, &body.params, &credentials, &config).await?;
    Ok(Json(json!({ "result": result })))
}
