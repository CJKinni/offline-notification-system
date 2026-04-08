use std::collections::HashMap;
use std::time::Instant;

use sqlx::SqlitePool;
use uuid::Uuid;

use crate::{
    agents::{
        orchestrator::run_agent,
        types::{AgentConfig, AgentRunRequest, Message, MessageRole, Provider},
        prompt_builder::build_system_prompt,
    },
    config::Config,
    flows::types::{FlowEdge, FlowNode, FlowRunContext, FlowRunResult, NodeType, RunStatus},
    utils::errors::{AppError, AppResult},
};

pub struct FlowExecutor {
    pub db: SqlitePool,
    pub config: Config,
}

impl FlowExecutor {
    pub async fn execute(
        &self,
        flow_id: &str,
        nodes: Vec<FlowNode>,
        edges: Vec<FlowEdge>,
        input: serde_json::Value,
    ) -> AppResult<FlowRunResult> {
        let run_id = Uuid::new_v4().to_string();
        let start = Instant::now();

        sqlx::query!(
            "INSERT INTO flow_runs (id, flow_id, status, input_json, started_at) VALUES (?,?,?,?,?)",
            run_id, flow_id, "running",
            serde_json::to_string(&input).ok(),
            chrono::Utc::now().timestamp()
        )
        .execute(&self.db)
        .await?;

        let mut ctx = FlowRunContext {
            flow_id: flow_id.to_string(),
            run_id: run_id.clone(),
            variables: HashMap::from([("input".to_string(), input)]),
            node_outputs: HashMap::new(),
        };
        let mut executed: Vec<String> = Vec::new();

        // Find start nodes (no incoming edges)
        let start_nodes: Vec<&FlowNode> = nodes
            .iter()
            .filter(|n| !edges.iter().any(|e| e.target == n.id))
            .collect();

        let result: AppResult<()> = async {
            for node in start_nodes {
                self.exec_node(node, &nodes, &edges, &mut ctx, &mut executed).await?;
            }
            Ok(())
        }.await;

        let duration = start.elapsed().as_millis() as u64;

        match result {
            Ok(_) => {
                let output = serde_json::to_value(&ctx.node_outputs).unwrap_or_default();
                sqlx::query!(
                    "UPDATE flow_runs SET status='success', output_json=?, completed_at=?, duration_ms=? WHERE id=?",
                    serde_json::to_string(&output).ok(),
                    chrono::Utc::now().timestamp(), duration as i64, run_id
                ).execute(&self.db).await?;
                Ok(FlowRunResult {
                    run_id, status: RunStatus::Success,
                    output, error: None, executed_nodes: executed, duration_ms: duration,
                })
            }
            Err(e) => {
                let err_str = e.to_string();
                sqlx::query!(
                    "UPDATE flow_runs SET status='error', error=?, completed_at=?, duration_ms=? WHERE id=?",
                    err_str, chrono::Utc::now().timestamp(), duration as i64, run_id
                ).execute(&self.db).await?;
                Ok(FlowRunResult {
                    run_id, status: RunStatus::Error,
                    output: serde_json::Value::Null,
                    error: Some(err_str),
                    executed_nodes: executed, duration_ms: duration,
                })
            }
        }
    }

    async fn exec_node<'a>(
        &self,
        node: &'a FlowNode,
        all_nodes: &'a [FlowNode],
        edges: &'a [FlowEdge],
        ctx: &mut FlowRunContext,
        executed: &mut Vec<String>,
    ) -> AppResult<()> {
        if executed.contains(&node.id) {
            return Ok(());
        }
        executed.push(node.id.clone());

        let output = self.run_node_logic(node, ctx).await?;
        ctx.node_outputs.insert(node.id.clone(), output);

        let outgoing: Vec<&FlowEdge> = edges.iter().filter(|e| e.source == node.id).collect();
        for edge in outgoing {
            if let Some(cond) = &edge.condition {
                if !self.eval_condition(cond, ctx) {
                    continue;
                }
            }
            if let Some(next) = all_nodes.iter().find(|n| n.id == edge.target) {
                Box::pin(self.exec_node(next, all_nodes, edges, ctx, executed)).await?;
            }
        }
        Ok(())
    }

    async fn run_node_logic(
        &self,
        node: &FlowNode,
        ctx: &FlowRunContext,
    ) -> AppResult<serde_json::Value> {
        match node.node_type {
            NodeType::Trigger => {
                Ok(ctx.variables.get("input").cloned().unwrap_or(serde_json::Value::Null))
            }
            NodeType::Agent => {
                let prompt = node.config["prompt"].as_str().unwrap_or("").to_string();
                let agent_id = node.config["agent_id"].as_str().unwrap_or("");
                let provider_str = node.config["provider"].as_str().unwrap_or("claude");
                let model = node.config["model"].as_str().unwrap_or("claude-sonnet-4-6");

                let prompt = if node.config["use_context"].as_bool().unwrap_or(false) {
                    let prev = ctx.node_outputs.values().last()
                        .map(|v| v.to_string())
                        .unwrap_or_default();
                    format!("{}\n\nContext: {}", prompt, prev)
                } else {
                    prompt
                };

                let system = if !agent_id.is_empty() {
                    build_system_prompt(agent_id, None, &self.db).await?.system
                } else {
                    "You are a helpful AI agent in a workflow.".to_string()
                };

                let provider: Provider = provider_str.parse().unwrap_or(Provider::Claude);
                let config = AgentConfig {
                    id: node.id.clone(),
                    name: node.label.clone(),
                    provider,
                    model: model.to_string(),
                    system_prompt: Some(system),
                    temperature: 0.7,
                    max_tokens: 2048,
                    fallback_provider: None,
                    fallback_model: None,
                };

                let resp = run_agent(
                    AgentRunRequest {
                        config,
                        messages: vec![Message { role: MessageRole::User, content: prompt }],
                        stream_tx: None,
                    },
                    &self.config,
                ).await?;

                Ok(serde_json::Value::String(resp.content))
            }
            NodeType::Delay => {
                let ms = node.config["ms"].as_u64().unwrap_or(1000);
                tokio::time::sleep(std::time::Duration::from_millis(ms)).await;
                Ok(serde_json::Value::Null)
            }
            NodeType::Transform => {
                let template = node.config["template"].as_str().unwrap_or("");
                Ok(serde_json::Value::String(self.interpolate(template, ctx)))
            }
            NodeType::Output | NodeType::Condition | NodeType::Integration => {
                Ok(serde_json::to_value(&ctx.node_outputs).unwrap_or_default())
            }
        }
    }

    fn eval_condition(&self, condition: &str, ctx: &FlowRunContext) -> bool {
        // Simple field-based conditions: "field operator value"
        let parts: Vec<&str> = condition.splitn(3, ' ').collect();
        if parts.len() != 3 { return true; }
        let val = ctx.node_outputs.get(parts[0])
            .or_else(|| ctx.variables.get(parts[0]))
            .map(|v| v.to_string())
            .unwrap_or_default();
        match parts[1] {
            "==" => val == parts[2],
            "!=" => val != parts[2],
            "contains" => val.contains(parts[2]),
            ">" => val.parse::<f64>().ok().zip(parts[2].parse::<f64>().ok())
                .map_or(false, |(a, b)| a > b),
            "<" => val.parse::<f64>().ok().zip(parts[2].parse::<f64>().ok())
                .map_or(false, |(a, b)| a < b),
            _ => true,
        }
    }

    fn interpolate(&self, template: &str, ctx: &FlowRunContext) -> String {
        let mut result = template.to_string();
        for (k, v) in &ctx.node_outputs {
            result = result.replace(&format!("{{{{{k}}}}}"), &v.to_string());
        }
        for (k, v) in &ctx.variables {
            result = result.replace(&format!("{{{{{k}}}}}"), &v.to_string());
        }
        result
    }
}
