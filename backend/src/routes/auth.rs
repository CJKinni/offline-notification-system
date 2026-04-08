use axum::{extract::State, Json};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use crate::{
    utils::{auth::{sign_token, AuthUser}, errors::{AppError, AppResult}},
    AppState,
};

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub token: String,
    pub user_id: String,
    pub email: String,
    pub tier: String,
}

pub async fn register(
    State(state): State<AppState>,
    Json(body): Json<RegisterRequest>,
) -> AppResult<Json<AuthResponse>> {
    let existing = sqlx::query!("SELECT id FROM users WHERE email = ?", body.email)
        .fetch_optional(&state.db)
        .await?;

    if existing.is_some() {
        return Err(AppError::BadRequest("Email already registered".into()));
    }

    let hash = argon2::password_hash::PasswordHash::generate(
        argon2::Argon2::default(),
        body.password.as_bytes(),
        &argon2::password_hash::SaltString::generate(&mut argon2::password_hash::rand_core::OsRng),
    ).map_err(|e| AppError::Internal(anyhow::anyhow!(e.to_string())))?
     .to_string();

    let user_id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)",
        user_id, body.email, hash
    )
    .execute(&state.db)
    .await?;

    let token = sign_token(&user_id, &body.email, "free", &state.config.jwt_secret)
        .map_err(|e| AppError::Internal(e))?;

    Ok(Json(AuthResponse { token, user_id, email: body.email, tier: "free".into() }))
}

pub async fn login(
    State(state): State<AppState>,
    Json(body): Json<LoginRequest>,
) -> AppResult<Json<AuthResponse>> {
    let user = sqlx::query!(
        "SELECT id, email, password_hash, subscription_tier FROM users WHERE email = ?",
        body.email
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or_else(|| AppError::Unauthorized("Invalid credentials".into()))?;

    let parsed = argon2::password_hash::PasswordHash::new(&user.password_hash)
        .map_err(|_| AppError::Unauthorized("Invalid credentials".into()))?;
    argon2::PasswordVerifier::verify_password(
        &argon2::Argon2::default(),
        body.password.as_bytes(),
        &parsed,
    ).map_err(|_| AppError::Unauthorized("Invalid credentials".into()))?;

    let token = sign_token(&user.id, &user.email, &user.subscription_tier, &state.config.jwt_secret)
        .map_err(|e| AppError::Internal(e))?;

    Ok(Json(AuthResponse {
        token,
        user_id: user.id,
        email: user.email,
        tier: user.subscription_tier,
    }))
}

pub async fn me(auth: AuthUser) -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "id": auth.0.sub,
        "email": auth.0.email,
        "tier": auth.0.tier,
    }))
}
