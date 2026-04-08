use async_trait::async_trait;
use serde_json::{json, Value};
use crate::{integrations::Integration, utils::errors::{AppError, AppResult}};

pub struct WebhookIntegration;

#[async_trait]
impl Integration for WebhookIntegration {
    fn integration_type(&self) -> &'static str { "webhook" }

    async fn test(&self, config: &Value, _credentials: &Value) -> AppResult<bool> {
        let url = config["url"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing webhook url".into()))?;
        let client = reqwest::Client::new();
        let resp = client
            .post(url)
            .json(&json!({ "type": "ping", "source": "hermes" }))
            .send().await
            .map_err(|e| AppError::Internal(e.into()))?;
        Ok(resp.status().is_success())
    }

    async fn execute(&self, action: &str, params: &Value, _credentials: &Value) -> AppResult<Value> {
        match action {
            "send" => {
                let url = params["url"].as_str()
                    .ok_or_else(|| AppError::BadRequest("Missing url".into()))?;
                let payload = params.get("payload").cloned().unwrap_or(json!({}));
                let client = reqwest::Client::new();
                let resp = client
                    .post(url)
                    .json(&payload)
                    .send().await
                    .map_err(|e| AppError::Internal(e.into()))?;
                let status = resp.status().as_u16();
                let body: Value = resp.json().await.unwrap_or(json!({}));
                Ok(json!({ "status": status, "body": body }))
            }
            _ => Err(AppError::BadRequest(format!("Unknown webhook action: {action}"))),
        }
    }
}
