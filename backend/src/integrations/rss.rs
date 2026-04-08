use async_trait::async_trait;
use serde_json::{json, Value};
use crate::{integrations::Integration, utils::errors::{AppError, AppResult}};

pub struct RssIntegration;

#[async_trait]
impl Integration for RssIntegration {
    fn integration_type(&self) -> &'static str { "rss" }

    async fn test(&self, config: &Value, _credentials: &Value) -> AppResult<bool> {
        let url = config["url"].as_str()
            .ok_or_else(|| AppError::BadRequest("Missing feed url".into()))?;
        let client = reqwest::Client::new();
        let resp = client.get(url).send().await.map_err(|e| AppError::Internal(e.into()))?;
        Ok(resp.status().is_success())
    }

    async fn execute(&self, action: &str, params: &Value, _credentials: &Value) -> AppResult<Value> {
        match action {
            "fetch" => {
                let url = params["url"].as_str()
                    .ok_or_else(|| AppError::BadRequest("Missing feed url".into()))?;
                let limit = params["limit"].as_u64().unwrap_or(10) as usize;

                let client = reqwest::Client::new();
                let xml = client
                    .get(url)
                    .header("User-Agent", "Hermes/1.0")
                    .send().await
                    .map_err(|e| AppError::Internal(e.into()))?
                    .text().await
                    .map_err(|e| AppError::Internal(e.into()))?;

                let items = parse_feed(&xml, limit);
                Ok(json!({ "items": items, "count": items.len() }))
            }
            _ => Err(AppError::BadRequest(format!("Unknown RSS action: {action}"))),
        }
    }
}

fn parse_feed(xml: &str, limit: usize) -> Vec<Value> {
    // Simple regex-free XML parsing for RSS/Atom items
    let mut items = Vec::new();
    let mut remaining = xml;

    while items.len() < limit {
        // Try RSS <item> tags first, then Atom <entry>
        let (start_tag, end_tag) = if let Some(pos) = remaining.find("<item>") {
            ("<item>", "</item>")
        } else if let Some(_) = remaining.find("<entry>") {
            ("<entry>", "</entry>")
        } else {
            break;
        };

        let start = match remaining.find(start_tag) {
            Some(p) => p,
            None => break,
        };
        let end = match remaining[start..].find(end_tag) {
            Some(p) => start + p + end_tag.len(),
            None => break,
        };

        let item_xml = &remaining[start..end];
        let title = extract_tag(item_xml, "title").unwrap_or_default();
        let link = extract_tag(item_xml, "link").unwrap_or_default();
        let summary = extract_tag(item_xml, "description")
            .or_else(|| extract_tag(item_xml, "summary"))
            .unwrap_or_default();
        let pub_date = extract_tag(item_xml, "pubDate")
            .or_else(|| extract_tag(item_xml, "updated"))
            .unwrap_or_default();

        items.push(json!({
            "title": title,
            "link": link,
            "summary": summary,
            "pub_date": pub_date,
        }));

        remaining = &remaining[end..];
    }

    items
}

fn extract_tag(xml: &str, tag: &str) -> Option<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let start = xml.find(&open)? + open.len();
    let end = xml[start..].find(&close)? + start;
    let content = xml[start..end].trim();
    // Strip CDATA
    let content = content
        .trim_start_matches("<![CDATA[")
        .trim_end_matches("]]>");
    Some(content.to_string())
}
