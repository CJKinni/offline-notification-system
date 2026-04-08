use axum::{extract::{Path, State}, Json};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use crate::{
    agents::{
        orchestrator::run_agent,
        prompt_builder::build_system_prompt,
        types::{AgentConfig, AgentRunRequest, Message, MessageRole, Provider, StreamChunk},
    },
    utils::{auth::AuthUser, errors::{AppError, AppResult}},
    AppState,
};

pub async fn list(auth: AuthUser, State(s): State<AppState>) -> AppResult<Json<serde_json::Value>> {
    let rows = sqlx::query!(
        "SELECT c.id, c.title, c.created_at, a.name as agent_name, a.provider
         FROM conversations c JOIN agents a ON a.id = c.agent_id
         WHERE c.user_id = ? ORDER BY c.updated_at DESC LIMIT 50",
        auth.0.sub
    )
    .fetch_all(&s.db).await?;
    let list: Vec<_> = rows.iter().map(|r| json!({
        "id": r.id, "title": r.title, "agent_name": r.agent_name,
        "provider": r.provider, "created_at": r.created_at
    })).collect();
    Ok(Json(json!({ "conversations": list })))
}

#[derive(Deserialize)]
pub struct CreateConvoRequest {
    pub agent_id: String,
    pub title: Option<String>,
}

pub async fn create(
    auth: AuthUser,
    State(s): State<AppState>,
    Json(body): Json<CreateConvoRequest>,
) -> AppResult<Json<serde_json::Value>> {
    let id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO conversations (id, user_id, agent_id, title) VALUES (?,?,?,?)",
        id, auth.0.sub, body.agent_id, body.title
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "id": id })))
}

pub async fn get(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    let convo = sqlx::query!(
        "SELECT * FROM conversations WHERE id = ? AND user_id = ?",
        id, auth.0.sub
    )
    .fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Conversation not found".into()))?;

    let messages = sqlx::query!(
        "SELECT id, role, content, provider, model, tokens_used, created_at
         FROM messages WHERE conversation_id = ? ORDER BY created_at ASC",
        id
    )
    .fetch_all(&s.db).await?;

    let msgs: Vec<_> = messages.iter().map(|m| json!({
        "id": m.id, "role": m.role, "content": m.content,
        "provider": m.provider, "model": m.model, "created_at": m.created_at
    })).collect();

    Ok(Json(json!({
        "id": convo.id, "title": convo.title,
        "agent_id": convo.agent_id, "messages": msgs
    })))
}

pub async fn delete(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(id): Path<String>,
) -> AppResult<Json<serde_json::Value>> {
    sqlx::query!(
        "DELETE FROM conversations WHERE id = ? AND user_id = ?",
        id, auth.0.sub
    )
    .execute(&s.db).await?;
    Ok(Json(json!({ "deleted": true })))
}

#[derive(Deserialize)]
pub struct SendMessageRequest {
    pub content: String,
}

pub async fn send_message(
    auth: AuthUser,
    State(s): State<AppState>,
    Path(convo_id): Path<String>,
    Json(body): Json<SendMessageRequest>,
) -> AppResult<Json<serde_json::Value>> {
    // Verify conversation belongs to user and get agent
    let convo = sqlx::query!(
        "SELECT agent_id FROM conversations WHERE id = ? AND user_id = ?",
        convo_id, auth.0.sub
    )
    .fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Conversation not found".into()))?;

    let agent = sqlx::query!(
        "SELECT id, provider, model, system_prompt, temperature, max_tokens,
         fallback_provider, fallback_model FROM agents WHERE id = ?",
        convo.agent_id
    )
    .fetch_optional(&s.db).await?
    .ok_or_else(|| AppError::NotFound("Agent not found".into()))?;

    // Load conversation history (last 20 messages)
    let history = sqlx::query!(
        "SELECT role, content FROM messages
         WHERE conversation_id = ? ORDER BY created_at ASC LIMIT 20",
        convo_id
    )
    .fetch_all(&s.db).await?;

    // Persist user message
    let user_msg_id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO messages (id, conversation_id, role, content) VALUES (?,?,?,?)",
        user_msg_id, convo_id, "user", body.content
    )
    .execute(&s.db).await?;

    // Build system prompt (soul + memory + skills)
    let built = build_system_prompt(&agent.id, agent.system_prompt.as_deref(), &s.db).await?;

    let mut messages: Vec<Message> = history.iter().map(|m| Message {
        role: if m.role == "user" { MessageRole::User } else { MessageRole::Assistant },
        content: m.content.clone(),
    }).collect();
    messages.push(Message { role: MessageRole::User, content: body.content.clone() });

    let provider: Provider = agent.provider.parse().unwrap_or(Provider::Claude);
    let agent_config = AgentConfig {
        id: agent.id.clone(),
        name: "Agent".to_string(),
        provider,
        model: agent.model.clone(),
        system_prompt: Some(built.system),
        temperature: agent.temperature as f32,
        max_tokens: agent.max_tokens as u32,
        fallback_provider: agent.fallback_provider.as_deref().and_then(|p| p.parse().ok()),
        fallback_model: agent.fallback_model.clone(),
    };

    // Set up streaming channel
    let (tx, mut rx) = tokio::sync::mpsc::channel::<StreamChunk>(64);
    let emitter = s.emitter.clone();
    let convo_id_clone = convo_id.clone();
    let assistant_msg_id = Uuid::new_v4().to_string();
    let msg_id_clone = assistant_msg_id.clone();

    // Spawn streaming forwarder
    tokio::spawn(async move {
        while let Some(chunk) = rx.recv().await {
            if !chunk.done {
                emitter.emit_stream_chunk(&convo_id_clone, &msg_id_clone, &chunk.delta);
            }
        }
    });

    // Run agent
    let resp = run_agent(
        AgentRunRequest {
            config: agent_config,
            messages,
            stream_tx: Some(tx),
        },
        &s.config,
    ).await?;

    // Persist assistant message
    let tokens = resp.tokens_used.map(|t| t as i64);
    let provider_str = resp.provider.to_string();
    sqlx::query!(
        "INSERT INTO messages (id, conversation_id, role, content, provider, model, tokens_used, used_fallback)
         VALUES (?,?,?,?,?,?,?,?)",
        assistant_msg_id, convo_id, "assistant", resp.content,
        provider_str, resp.model, tokens, resp.used_fallback
    )
    .execute(&s.db).await?;

    // Emit done
    s.emitter.emit_stream_done(&convo_id, &assistant_msg_id, &resp.content, resp.tokens_used);

    // Update conversation timestamp
    sqlx::query!(
        "UPDATE conversations SET updated_at = unixepoch() WHERE id = ?",
        convo_id
    )
    .execute(&s.db).await?;

    Ok(Json(json!({
        "message_id": assistant_msg_id,
        "content": resp.content,
        "provider": resp.provider.to_string(),
        "model": resp.model,
        "tokens_used": resp.tokens_used,
        "used_fallback": resp.used_fallback,
    })))
}
