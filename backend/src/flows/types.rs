use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NodeType {
    Trigger,
    Agent,
    Condition,
    Transform,
    Integration,
    Delay,
    Output,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlowNode {
    pub id: String,
    #[serde(rename = "type")]
    pub node_type: NodeType,
    pub label: String,
    pub config: serde_json::Value,
    pub position: Option<Position>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Position {
    pub x: f32,
    pub y: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FlowEdge {
    pub id: String,
    pub source: String,
    pub target: String,
    pub label: Option<String>,
    pub condition: Option<String>,
}

#[derive(Debug, Clone)]
pub struct FlowRunContext {
    pub flow_id: String,
    pub run_id: String,
    pub variables: HashMap<String, serde_json::Value>,
    pub node_outputs: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FlowRunResult {
    pub run_id: String,
    pub status: RunStatus,
    pub output: serde_json::Value,
    pub error: Option<String>,
    pub executed_nodes: Vec<String>,
    pub duration_ms: u64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RunStatus {
    Success,
    Error,
    Partial,
}
