use crate::agents::types::{AgentConfig, AgentResponse, Message, MessageRole, Provider, StreamChunk};
use crate::utils::errors::AppError;
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Serialize)]
struct ClaudeRequest {
    model: String,
    max_tokens: u32,
    system: String,
    messages: Vec<ClaudeMessage>,
    stream: bool,
    temperature: f32,
}

#[derive(Serialize, Deserialize)]
struct ClaudeMessage {
    role: String,
    content: String,
}

pub async fn run(
    config: &AgentConfig,
    messages: &[Message],
    system_prompt: &str,
    api_key: &str,
    stream_tx: Option<&tokio::sync::mpsc::Sender<StreamChunk>>,
) -> Result<AgentResponse, AppError> {
    let client = reqwest::Client::new();
    let claude_messages: Vec<ClaudeMessage> = messages
        .iter()
        .filter(|m| m.role != MessageRole::System)
        .map(|m| ClaudeMessage {
            role: m.role.to_string(),
            content: m.content.clone(),
        })
        .collect();

    let streaming = stream_tx.is_some();
    let body = ClaudeRequest {
        model: config.model.clone(),
        max_tokens: config.max_tokens,
        system: system_prompt.to_string(),
        messages: claude_messages,
        stream: streaming,
        temperature: config.temperature,
    };

    let response = client
        .post("https://api.anthropic.com/v1/messages")
        .header("x-api-key", api_key)
        .header("anthropic-version", "2023-06-01")
        .header("content-type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| AppError::ProviderError {
            provider: "claude".into(),
            message: e.to_string(),
        })?;

    if !response.status().is_success() {
        let err_text = response.text().await.unwrap_or_default();
        return Err(AppError::ProviderError {
            provider: "claude".into(),
            message: err_text,
        });
    }

    if let Some(tx) = stream_tx {
        let mut full_content = String::new();
        let mut stream = response.bytes_stream();

        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| AppError::ProviderError {
                provider: "claude".into(),
                message: e.to_string(),
            })?;
            let text = String::from_utf8_lossy(&chunk);
            for line in text.lines() {
                if let Some(data) = line.strip_prefix("data: ") {
                    if data == "[DONE]" { break; }
                    if let Ok(v) = serde_json::from_str::<Value>(data) {
                        if v["type"] == "content_block_delta" {
                            if let Some(delta) = v["delta"]["text"].as_str() {
                                full_content.push_str(delta);
                                let _ = tx.send(StreamChunk { delta: delta.to_string(), done: false }).await;
                            }
                        }
                    }
                }
            }
        }

        let _ = tx.send(StreamChunk { delta: String::new(), done: true }).await;

        Ok(AgentResponse {
            content: full_content,
            provider: Provider::Claude,
            model: config.model.clone(),
            tokens_used: None,
            used_fallback: false,
        })
    } else {
        let body: Value = response.json().await.map_err(|e| AppError::ProviderError {
            provider: "claude".into(),
            message: e.to_string(),
        })?;
        let content = body["content"][0]["text"].as_str().unwrap_or("").to_string();
        let tokens = body["usage"]["output_tokens"].as_u64().map(|t| t as u32);
        Ok(AgentResponse {
            content,
            provider: Provider::Claude,
            model: config.model.clone(),
            tokens_used: tokens,
            used_fallback: false,
        })
    }
}
