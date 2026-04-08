use async_trait::async_trait;
use serde_json::{json, Value};
use crate::{integrations::Integration, utils::errors::{AppError, AppResult}};

pub struct CalendarIntegration;

#[async_trait]
impl Integration for CalendarIntegration {
    fn integration_type(&self) -> &'static str { "calendar" }

    async fn test(&self, _config: &Value, credentials: &Value) -> AppResult<bool> {
        let token = credentials["access_token"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing access_token".into()))?;
        let client = reqwest::Client::new();
        let resp = client
            .get("https://www.googleapis.com/calendar/v3/users/me/calendarList")
            .header("Authorization", format!("Bearer {token}"))
            .send().await.map_err(|e| AppError::Internal(e.into()))?;
        Ok(resp.status().is_success())
    }

    async fn execute(&self, action: &str, params: &Value, credentials: &Value) -> AppResult<Value> {
        let token = credentials["access_token"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing access_token".into()))?;
        let client = reqwest::Client::new();
        let cal_id = params["calendar_id"].as_str().unwrap_or("primary");

        match action {
            "list_events" => {
                let time_min = params["time_min"].as_str().unwrap_or("");
                let url = format!(
                    "https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events?timeMin={time_min}&singleEvents=true&orderBy=startTime"
                );
                let resp = client
                    .get(&url)
                    .header("Authorization", format!("Bearer {token}"))
                    .send().await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            "create_event" => {
                let url = format!(
                    "https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events"
                );
                let resp = client
                    .post(&url)
                    .header("Authorization", format!("Bearer {token}"))
                    .json(params)
                    .send().await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(resp.json().await.map_err(|e| AppError::Internal(e.into()))?)
            }
            "delete_event" => {
                let event_id = params["event_id"].as_str()
                    .ok_or_else(|| AppError::BadRequest("Missing event_id".into()))?;
                let url = format!(
                    "https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events/{event_id}"
                );
                client.delete(&url)
                    .header("Authorization", format!("Bearer {token}"))
                    .send().await.map_err(|e| AppError::Internal(e.into()))?;
                Ok(json!({ "success": true }))
            }
            _ => Err(AppError::BadRequest(format!("Unknown Calendar action: {action}"))),
        }
    }
}
