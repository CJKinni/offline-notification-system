//! OpenAI-compatible provider — used for OpenAI and MiniMax (same API shape)
use crate::agents::types::{AgentConfig, AgentResponse, Message, MessageRole, Provider, StreamChunk};
use crate::utils::errors::AppError;
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Serialize)]
struct OAIRequest<'a> {
    model: &'a str,
    messages: Vec<OAIMessage>,
    stream: bool,
    temperature: f32,
    max_tokens: u32,
}

#[derive(Serialize, Deserialize)]
struct OAIMessage {
    role: String,
    content: String,
}

pub async fn run(
    config: &AgentConfig,
    messages: &[Message],
    system_prompt: &str,
    api_key: &str,
    base_url: &str,
    result_provider: Provider,
    stream_tx: Option<&tokio::sync::mpsc::Sender<StreamChunk>>,
) -> Result<AgentResponse, AppError> {
    let client = reqwest::Client::new();
    let mut oai_messages = vec![OAIMessage {
        role: "system".to_string(),
        content: system_prompt.to_string(),
    }];
    oai_messages.extend(
        messages
            .iter()
            .filter(|m| m.role != MessageRole::System)
            .map(|m| OAIMessage {
                role: m.role.to_string(),
                content: m.content.clone(),
            }),
    );

    let streaming = stream_tx.is_some();
    let url = format!("{base_url}/chat/completions");
    let body = OAIRequest {
        model: &config.model,
        messages: oai_messages,
        stream: streaming,
        temperature: config.temperature,
        max_tokens: config.max_tokens,
    };

    let response = client
        .post(&url)
        .header("Authorization", format!("Bearer {api_key}"))
        .header("content-type", "application/json")
        .json(&body)
        .send()
        .await
        .map_err(|e| AppError::ProviderError {
            provider: result_provider.to_string(),
            message: e.to_string(),
        })?;

    if !response.status().is_success() {
        let err = response.text().await.unwrap_or_default();
        return Err(AppError::ProviderError {
            provider: result_provider.to_string(),
            message: err,
        });
    }

    if let Some(tx) = stream_tx {
        let mut full_content = String::new();
        let mut stream = response.bytes_stream();

        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| AppError::ProviderError {
                provider: result_provider.to_string(),
                message: e.to_string(),
            })?;
            let text = String::from_utf8_lossy(&chunk);
            for line in text.lines() {
                if let Some(data) = line.strip_prefix("data: ") {
                    if data.trim() == "[DONE]" { break; }
                    if let Ok(v) = serde_json::from_str::<Value>(data) {
                        if let Some(delta) = v["choices"][0]["delta"]["content"].as_str() {
                            if !delta.is_empty() {
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
            provider: result_provider,
            model: config.model.clone(),
            tokens_used: None,
            used_fallback: false,
        })
    } else {
        let body: Value = response.json().await.map_err(|e| AppError::ProviderError {
            provider: result_provider.to_string(),
            message: e.to_string(),
        })?;
        let content = body["choices"][0]["message"]["content"].as_str().unwrap_or("").to_string();
        let tokens = body["usage"]["total_tokens"].as_u64().map(|t| t as u32);
        Ok(AgentResponse {
            content,
            provider: result_provider,
            model: config.model.clone(),
            tokens_used: tokens,
            used_fallback: false,
        })
    }
}
