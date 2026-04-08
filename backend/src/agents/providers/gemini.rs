use crate::agents::types::{AgentConfig, AgentResponse, Message, MessageRole, Provider, StreamChunk};
use crate::utils::errors::AppError;
use serde_json::{json, Value};

pub async fn run(
    config: &AgentConfig,
    messages: &[Message],
    system_prompt: &str,
    api_key: &str,
    _stream_tx: Option<&tokio::sync::mpsc::Sender<StreamChunk>>,
) -> Result<AgentResponse, AppError> {
    let client = reqwest::Client::new();
    let contents: Vec<Value> = messages
        .iter()
        .filter(|m| m.role != MessageRole::System)
        .map(|m| {
            json!({
                "role": if m.role == MessageRole::Assistant { "model" } else { "user" },
                "parts": [{ "text": m.content }]
            })
        })
        .collect();

    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}",
        config.model, api_key
    );

    let body = json!({
        "contents": contents,
        "systemInstruction": { "parts": [{ "text": system_prompt }] },
        "generationConfig": {
            "temperature": config.temperature,
            "maxOutputTokens": config.max_tokens
        }
    });

    let response = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .map_err(|e| AppError::ProviderError { provider: "gemini".into(), message: e.to_string() })?;

    if !response.status().is_success() {
        let err = response.text().await.unwrap_or_default();
        return Err(AppError::ProviderError { provider: "gemini".into(), message: err });
    }

    let data: Value = response.json().await.map_err(|e| AppError::ProviderError {
        provider: "gemini".into(), message: e.to_string(),
    })?;

    let content = data["candidates"][0]["content"]["parts"][0]["text"]
        .as_str()
        .unwrap_or("")
        .to_string();
    let tokens = data["usageMetadata"]["totalTokenCount"].as_u64().map(|t| t as u32);

    Ok(AgentResponse {
        content,
        provider: Provider::Gemini,
        model: config.model.clone(),
        tokens_used: tokens,
        used_fallback: false,
    })
}
