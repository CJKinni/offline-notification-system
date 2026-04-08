use async_trait::async_trait;
use serde_json::{json, Value};
use crate::{integrations::Integration, utils::errors::{AppError, AppResult}};

pub struct GmailIntegration;

#[async_trait]
impl Integration for GmailIntegration {
    fn integration_type(&self) -> &'static str { "gmail" }

    async fn test(&self, _config: &Value, credentials: &Value) -> AppResult<bool> {
        let token = credentials["access_token"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing access_token".into()))?;
        let client = reqwest::Client::new();
        let resp = client
            .get("https://gmail.googleapis.com/gmail/v1/users/me/profile")
            .header("Authorization", format!("Bearer {token}"))
            .send().await
            .map_err(|e| AppError::Internal(e.into()))?;
        Ok(resp.status().is_success())
    }

    async fn execute(&self, action: &str, params: &Value, credentials: &Value) -> AppResult<Value> {
        let token = credentials["access_token"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing access_token".into()))?;
        let client = reqwest::Client::new();

        match action {
            "list_emails" => {
                let max = params["max_results"].as_u64().unwrap_or(10);
                let query = params["query"].as_str().unwrap_or("in:inbox");
                let url = format!(
                    "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults={max}&q={query}"
                );
                let resp = client
                    .get(&url)
                    .header("Authorization", format!("Bearer {token}"))
                    .send().await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            "get_email" => {
                let id = params["id"].as_str()
                    .ok_or_else(|| AppError::BadRequest("Missing email id".into()))?;
                let url = format!(
                    "https://gmail.googleapis.com/gmail/v1/users/me/messages/{id}?format=full"
                );
                let resp = client
                    .get(&url)
                    .header("Authorization", format!("Bearer {token}"))
                    .send().await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            "send_email" => {
                let to = params["to"].as_str().unwrap_or("");
                let subject = params["subject"].as_str().unwrap_or("");
                let body_text = params["body"].as_str().unwrap_or("");
                let raw = base64::Engine::encode(
                    &base64::engine::general_purpose::URL_SAFE,
                    format!("To: {to}\r\nSubject: {subject}\r\n\r\n{body_text}"),
                );
                let resp = client
                    .post("https://gmail.googleapis.com/gmail/v1/users/me/messages/send")
                    .header("Authorization", format!("Bearer {token}"))
                    .json(&json!({ "raw": raw }))
                    .send().await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            _ => Err(AppError::BadRequest(format!("Unknown Gmail action: {action}"))),
        }
    }
}
