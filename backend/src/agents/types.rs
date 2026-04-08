use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Provider {
    Claude,
    OpenAI,
    Gemini,
    Ollama,
    MiniMax,
}

impl fmt::Display for Provider {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Provider::Claude => write!(f, "claude"),
            Provider::OpenAI => write!(f, "openai"),
            Provider::Gemini => write!(f, "gemini"),
            Provider::Ollama => write!(f, "ollama"),
            Provider::MiniMax => write!(f, "minimax"),
        }
    }
}

impl std::str::FromStr for Provider {
    type Err = anyhow::Error;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "claude" => Ok(Provider::Claude),
            "openai" => Ok(Provider::OpenAI),
            "gemini" => Ok(Provider::Gemini),
            "ollama" => Ok(Provider::Ollama),
            "minimax" => Ok(Provider::MiniMax),
            _ => Err(anyhow::anyhow!("Unknown provider: {s}")),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    pub id: String,
    pub name: String,
    pub provider: Provider,
    pub model: String,
    pub system_prompt: Option<String>,
    pub temperature: f32,
    pub max_tokens: u32,
    pub fallback_provider: Option<Provider>,
    pub fallback_model: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: MessageRole,
    pub content: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum MessageRole {
    User,
    Assistant,
    System,
}

impl fmt::Display for MessageRole {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MessageRole::User => write!(f, "user"),
            MessageRole::Assistant => write!(f, "assistant"),
            MessageRole::System => write!(f, "system"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentResponse {
    pub content: String,
    pub provider: Provider,
    pub model: String,
    pub tokens_used: Option<u32>,
    pub used_fallback: bool,
}

#[derive(Debug, Clone)]
pub struct StreamChunk {
    pub delta: String,
    pub done: bool,
}

pub struct AgentRunRequest {
    pub config: AgentConfig,
    pub messages: Vec<Message>,
    pub stream_tx: Option<tokio::sync::mpsc::Sender<StreamChunk>>,
}

/// Default models per provider
pub fn default_models(provider: &Provider) -> Vec<&'static str> {
    match provider {
        Provider::Claude => vec![
            "claude-opus-4-6",
            "claude-sonnet-4-6",
            "claude-haiku-4-5-20251001",
        ],
        Provider::OpenAI => vec!["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
        Provider::Gemini => vec!["gemini-1.5-pro", "gemini-1.5-flash"],
        Provider::Ollama => vec!["llama3", "mistral", "codellama", "phi3"],
        Provider::MiniMax => vec!["MiniMax-Text-01", "abab6.5s-chat"],
    }
}
