use async_trait::async_trait;
use serde_json::{json, Value};
use crate::{integrations::Integration, utils::errors::{AppError, AppResult}};

pub struct SlackIntegration;

#[async_trait]
impl Integration for SlackIntegration {
    fn integration_type(&self) -> &'static str { "slack" }

    async fn test(&self, _config: &Value, credentials: &Value) -> AppResult<bool> {
        let token = credentials["bot_token"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing bot_token".into()))?;
        let client = reqwest::Client::new();
        let resp = client
            .post("https://slack.com/api/auth.test")
            .header("Authorization", format!("Bearer {token}"))
            .send().await
            .map_err(|e| AppError::Internal(e.into()))?;
        let body: Value = resp.json().await.map_err(|e| AppError::Internal(e.into()))?;
        Ok(body["ok"].as_bool().unwrap_or(false))
    }

    async fn execute(&self, action: &str, params: &Value, credentials: &Value) -> AppResult<Value> {
        let token = credentials["bot_token"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing bot_token".into()))?;
        let client = reqwest::Client::new();
        match action {
            "post_message" => {
                let channel = params["channel"].as_str().unwrap_or("");
                let text = params["text"].as_str().unwrap_or("");
                let resp = client
                    .post("https://slack.com/api/chat.postMessage")
                    .header("Authorization", format!("Bearer {token}"))
                    .json(&json!({ "channel": channel, "text": text }))
                    .send().await
                    .map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            "list_channels" => {
                let resp = client
                    .get("https://slack.com/api/conversations.list")
                    .header("Authorization", format!("Bearer {token}"))
                    .send().await
                    .map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            _ => Err(AppError::BadRequest(format!("Unknown Slack action: {action}"))),
        }
    }
}
