use crate::{
    agents::{
        providers::{claude, gemini, ollama, openai_compat},
        types::{AgentResponse, AgentRunRequest, Provider, StreamChunk},
    },
    config::Config,
    utils::errors::{AppError, AppResult},
};

pub async fn run_agent(req: AgentRunRequest, cfg: &Config) -> AppResult<AgentResponse> {
    let stream_tx = req.stream_tx.as_ref();
    let result = dispatch(&req, cfg, &req.config.provider, &req.config.model, stream_tx).await;

    match result {
        Ok(mut resp) => {
            resp.used_fallback = false;
            Ok(resp)
        }
        Err(primary_err) => {
            tracing::warn!(
                "Primary provider {} failed: {}. Trying fallback...",
                req.config.provider,
                primary_err
            );

            if let (Some(fp), Some(fm)) = (
                &req.config.fallback_provider,
                &req.config.fallback_model,
            ) {
                // Re-create stream tx for fallback if streaming was requested
                match dispatch_with_model(&req, cfg, fp, fm, stream_tx).await {
                    Ok(mut resp) => {
                        resp.used_fallback = true;
                        tracing::info!("Fallback to {}/{} succeeded", fp, fm);
                        Ok(resp)
                    }
                    Err(fallback_err) => Err(AppError::FallbackFailed {
                        primary: primary_err.to_string(),
                        fallback: fallback_err.to_string(),
                    }),
                }
            } else {
                Err(primary_err)
            }
        }
    }
}

async fn dispatch(
    req: &AgentRunRequest,
    cfg: &Config,
    provider: &Provider,
    model: &str,
    stream_tx: Option<&tokio::sync::mpsc::Sender<StreamChunk>>,
) -> AppResult<AgentResponse> {
    let mut config = req.config.clone();
    config.model = model.to_string();
    let req_with_model = AgentRunRequest {
        config,
        messages: req.messages.clone(),
        stream_tx: None, // handled separately
    };
    dispatch_with_model(&req_with_model, cfg, provider, model, stream_tx).await
}

async fn dispatch_with_model(
    req: &AgentRunRequest,
    cfg: &Config,
    provider: &Provider,
    model: &str,
    stream_tx: Option<&tokio::sync::mpsc::Sender<StreamChunk>>,
) -> AppResult<AgentResponse> {
    let system = req.config.system_prompt.as_deref()
        .unwrap_or("You are Hermes, a helpful AI assistant.");

    let mut config = req.config.clone();
    config.provider = provider.clone();
    config.model = model.to_string();

    match provider {
        Provider::Claude => {
            let key = cfg.anthropic_api_key.as_deref()
                .ok_or_else(|| AppError::BadRequest("ANTHROPIC_API_KEY not configured".into()))?;
            claude::run(&config, &req.messages, system, key, stream_tx).await
        }
        Provider::OpenAI => {
            let key = cfg.openai_api_key.as_deref()
                .ok_or_else(|| AppError::BadRequest("OPENAI_API_KEY not configured".into()))?;
            openai_compat::run(
                &config, &req.messages, system, key,
                "https://api.openai.com/v1",
                Provider::OpenAI, stream_tx,
            ).await
        }
        Provider::MiniMax => {
            let key = cfg.minimax_api_key.as_deref()
                .ok_or_else(|| AppError::BadRequest("MINIMAX_API_KEY not configured".into()))?;
            openai_compat::run(
                &config, &req.messages, system, key,
                &cfg.minimax_base_url,
                Provider::MiniMax, stream_tx,
            ).await
        }
        Provider::Gemini => {
            let key = cfg.google_api_key.as_deref()
                .ok_or_else(|| AppError::BadRequest("GOOGLE_API_KEY not configured".into()))?;
            gemini::run(&config, &req.messages, system, key, stream_tx).await
        }
        Provider::Ollama => {
            ollama::run(&config, &req.messages, system, &cfg.ollama_base_url, stream_tx).await
        }
    }
}
