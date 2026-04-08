use sqlx::SqlitePool;
use std::sync::Arc;
use tokio::sync::RwLock;
use tokio_cron_scheduler::{Job, JobScheduler};
use uuid::Uuid;

use crate::{
    agents::{
        orchestrator::run_agent,
        prompt_builder::build_system_prompt,
        types::{AgentConfig, AgentRunRequest, Message, MessageRole, Provider},
    },
    config::Config,
    flows::{executor::FlowExecutor, types::FlowNode, types::FlowEdge},
    socket::EventEmitter,
};

pub struct CronScheduler {
    pub sched: JobScheduler,
    pub db: SqlitePool,
    pub config: Config,
    pub emitter: Arc<EventEmitter>,
}

#[derive(Debug, sqlx::FromRow)]
struct CronRow {
    id: String,
    name: String,
    schedule: String,
    flow_id: Option<String>,
    agent_id: Option<String>,
    prompt: Option<String>,
}

impl CronScheduler {
    pub async fn new(
        db: SqlitePool,
        config: Config,
        emitter: Arc<EventEmitter>,
    ) -> anyhow::Result<Self> {
        let sched = JobScheduler::new().await?;
        Ok(Self { sched, db, config, emitter })
    }

    pub async fn start(&mut self) -> anyhow::Result<()> {
        let rows: Vec<CronRow> = sqlx::query_as!(
            CronRow,
            "SELECT id, name, schedule, flow_id, agent_id, prompt FROM crons WHERE is_active = 1"
        )
        .fetch_all(&self.db)
        .await?;

        let count = rows.len();
        for row in rows {
            self.add_job(row).await?;
        }

        self.sched.start().await?;
        tracing::info!("Cron scheduler started with {} active jobs", count);
        Ok(())
    }

    async fn add_job(&mut self, row: CronRow) -> anyhow::Result<()> {
        let db = self.db.clone();
        let config = self.config.clone();
        let emitter = self.emitter.clone();
        let cron_id = row.id.clone();
        let cron_name = row.name.clone();

        let job = Job::new_async(&row.schedule, move |_uuid, _lock| {
            let db = db.clone();
            let config = config.clone();
            let emitter = emitter.clone();
            let cron_id = cron_id.clone();
            let cron_name = cron_name.clone();
            let row_flow_id = row.flow_id.clone();
            let row_agent_id = row.agent_id.clone();
            let row_prompt = row.prompt.clone();

            Box::pin(async move {
                tracing::info!("Cron firing: {}", cron_name);

                if let Some(flow_id) = row_flow_id {
                    if let Ok(flow_row) = sqlx::query!(
                        "SELECT nodes_json, edges_json FROM flows WHERE id = ?",
                        flow_id
                    )
                    .fetch_one(&db)
                    .await {
                        let nodes: Vec<FlowNode> = serde_json::from_str(&flow_row.nodes_json)
                            .unwrap_or_default();
                        let edges: Vec<FlowEdge> = serde_json::from_str(&flow_row.edges_json)
                            .unwrap_or_default();
                        let executor = FlowExecutor { db: db.clone(), config: config.clone() };
                        let _ = executor.execute(
                            &flow_id, nodes, edges,
                            serde_json::json!({"triggered_by": "cron", "cron_id": cron_id}),
                        ).await;
                    }
                } else if let (Some(agent_id), Some(prompt)) = (row_agent_id, row_prompt) {
                    if let Ok(agent) = sqlx::query!(
                        "SELECT provider, model, system_prompt, temperature, max_tokens,
                         fallback_provider, fallback_model
                         FROM agents WHERE id = ?",
                        agent_id
                    )
                    .fetch_one(&db)
                    .await {
                        let system = build_system_prompt(&agent_id, agent.system_prompt.as_deref(), &db)
                            .await
                            .map(|p| p.system)
                            .unwrap_or_default();

                        let provider: Provider = agent.provider.parse().unwrap_or(Provider::Claude);
                        let agent_config = AgentConfig {
                            id: agent_id.clone(),
                            name: "Cron Agent".to_string(),
                            provider,
                            model: agent.model,
                            system_prompt: Some(system),
                            temperature: agent.temperature as f32,
                            max_tokens: agent.max_tokens as u32,
                            fallback_provider: agent.fallback_provider
                                .as_deref()
                                .and_then(|p| p.parse().ok()),
                            fallback_model: agent.fallback_model,
                        };
                        let _ = run_agent(
                            AgentRunRequest {
                                config: agent_config,
                                messages: vec![Message { role: MessageRole::User, content: prompt }],
                                stream_tx: None,
                            },
                            &config,
                        ).await;
                    }
                }

                // Update stats
                let _ = sqlx::query!(
                    "UPDATE crons SET last_run_at = ?, run_count = run_count + 1 WHERE id = ?",
                    chrono::Utc::now().timestamp(), cron_id
                )
                .execute(&db)
                .await;

                // Emit socket event
                emitter.emit_cron_fired(&cron_id, &cron_name);
            })
        })?;

        self.sched.add(job).await?;
        Ok(())
    }
}
