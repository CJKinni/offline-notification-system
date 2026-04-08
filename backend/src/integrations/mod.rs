pub mod gmail;
pub mod calendar;
pub mod slack;
pub mod webhook;
pub mod rss;

use async_trait::async_trait;
use serde_json::Value;
use crate::utils::errors::AppResult;

#[async_trait]
pub trait Integration: Send + Sync {
    fn integration_type(&self) -> &'static str;
    async fn test(&self, config: &Value, credentials: &Value) -> AppResult<bool>;
    async fn execute(&self, action: &str, params: &Value, credentials: &Value) -> AppResult<Value>;
}

pub async fn execute_integration(
    integration_type: &str,
    action: &str,
    params: &Value,
    credentials: &Value,
    config: &Value,
) -> AppResult<Value> {
    match integration_type {
        "gmail" => gmail::GmailIntegration.execute(action, params, credentials).await,
        "calendar" => calendar::CalendarIntegration.execute(action, params, credentials).await,
        "slack" => slack::SlackIntegration.execute(action, params, credentials).await,
        "webhook" => webhook::WebhookIntegration.execute(action, params, credentials).await,
        "rss" => rss::RssIntegration.execute(action, params, credentials).await,
        _ => Err(crate::utils::errors::AppError::BadRequest(
            format!("Unknown integration type: {integration_type}")
        )),
    }
}
