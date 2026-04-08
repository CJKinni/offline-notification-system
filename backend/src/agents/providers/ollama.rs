use crate::agents::types::{AgentConfig, AgentResponse, Message, MessageRole, Provider, StreamChunk};
use crate::utils::errors::AppError;
use futures_util::StreamExt;
use serde_json::{json, Value};

pub async fn run(
    config: &AgentConfig,
    messages: &[Message],
    system_prompt: &str,
    base_url: &str,
    stream_tx: Option<&tokio::sync::mpsc::Sender<StreamChunk>>,
) -> Result<AgentResponse, AppError> {
    let client = reqwest::Client::new();

    // Build Ollama prompt format
    let mut prompt = format!("<|system|>\n{system_prompt}\n");
    for m in messages.iter().filter(|m| m.role != MessageRole::System) {
        prompt.push_str(&format!("<|{}|>\n{}\n", m.role, m.content));
    }
    prompt.push_str("<|assistant|>\n");

    let streaming = stream_tx.is_some();
    let body = json!({
        "model": config.model,
        "prompt": prompt,
        "stream": streaming,
        "options": {
            "temperature": config.temperature,
            "num_predict": config.max_tokens
        }
    });

    let url = format!("{base_url}/api/generate");
    let response = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .map_err(|e| AppError::ProviderError { provider: "ollama".into(), message: e.to_string() })?;

    if !response.status().is_success() {
        let err = response.text().await.unwrap_or_default();
        return Err(AppError::ProviderError { provider: "ollama".into(), message: err });
    }

    if let Some(tx) = stream_tx {
        let mut full_content = String::new();
        let mut stream = response.bytes_stream();

        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| AppError::ProviderError {
                provider: "ollama".into(), message: e.to_string(),
            })?;
            let text = String::from_utf8_lossy(&chunk);
            for line in text.lines() {
                if let Ok(v) = serde_json::from_str::<Value>(line) {
                    if let Some(delta) = v["response"].as_str() {
                        full_content.push_str(delta);
                        let _ = tx.send(StreamChunk { delta: delta.to_string(), done: false }).await;
                    }
                    if v["done"].as_bool().unwrap_or(false) {
                        let _ = tx.send(StreamChunk { delta: String::new(), done: true }).await;
                    }
                }
            }
        }

        Ok(AgentResponse {
            content: full_content,
            provider: Provider::Ollama,
            model: config.model.clone(),
            tokens_used: None,
            used_fallback: false,
        })
    } else {
        let data: Value = response.json().await.map_err(|e| AppError::ProviderError {
            provider: "ollama".into(), message: e.to_string(),
        })?;
        Ok(AgentResponse {
            content: data["response"].as_str().unwrap_or("").to_string(),
            provider: Provider::Ollama,
            model: config.model.clone(),
            tokens_used: None,
            used_fallback: false,
        })
    }
}
