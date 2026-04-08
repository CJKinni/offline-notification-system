use sqlx::SqlitePool;
use chrono::Local;
use crate::utils::errors::AppResult;

pub struct BuiltPrompt {
    pub system: String,
}

pub async fn build_system_prompt(
    agent_id: &str,
    base_prompt: Option<&str>,
    db: &SqlitePool,
) -> AppResult<BuiltPrompt> {
    let mut parts: Vec<String> = Vec::new();

    // Base identity
    let base = base_prompt.unwrap_or(
        "You are Hermes, a powerful personal AI assistant. \
         Be concise, accurate, and genuinely helpful."
    );
    parts.push(base.to_string());

    // Soul config (SOUL.md equivalent)
    let soul = sqlx::query!(
        "SELECT persona, tone, values_json, restrictions_json FROM soul_configs WHERE agent_id = ?",
        agent_id
    )
    .fetch_optional(db)
    .await?;

    if let Some(s) = soul {
        if !s.persona.is_empty() {
            parts.push(format!("## Persona\n{}", s.persona));
        }
        if !s.tone.is_empty() {
            parts.push(format!("## Tone\nRespond in a {} manner.", s.tone));
        }
        let values: Vec<String> = serde_json::from_str(&s.values_json).unwrap_or_default();
        if !values.is_empty() {
            parts.push(format!("## Core Values\n- {}", values.join("\n- ")));
        }
        let restrictions: Vec<String> = serde_json::from_str(&s.restrictions_json).unwrap_or_default();
        if !restrictions.is_empty() {
            parts.push(format!("## Restrictions\nDo NOT:\n- {}", restrictions.join("\n- ")));
        }
    }

    // Memory (openclaw MEMORY.md equivalent)
    let memory = sqlx::query!(
        "SELECT content_md FROM memories WHERE agent_id = ?",
        agent_id
    )
    .fetch_optional(db)
    .await?;

    if let Some(m) = memory {
        if !m.content_md.is_empty() {
            parts.push(format!("## My Memory\n{}", m.content_md));
        }
    }

    // Skills (SKILL.md equivalent) — cap at 5 to avoid prompt bloat
    let skills = sqlx::query!(
        r#"
        SELECT s.name, s.content_md
        FROM skills s
        JOIN agent_skills ags ON ags.skill_id = s.id
        WHERE ags.agent_id = ?
        ORDER BY s.usage_count DESC
        LIMIT 5
        "#,
        agent_id
    )
    .fetch_all(db)
    .await?;

    for skill in &skills {
        parts.push(format!("## Skill: {}\n{}", skill.name, skill.content_md));
    }

    // Current date/time
    parts.push(format!(
        "## Current Date & Time\n{}",
        Local::now().format("%A, %B %d, %Y at %H:%M %Z")
    ));

    // Assemble — crude token estimate: 1 token ≈ 4 chars, cap at ~32k chars (~8k tokens)
    let system = parts.join("\n\n");
    let system = if system.len() > 32_000 {
        system[..32_000].to_string()
    } else {
        system
    };

    Ok(BuiltPrompt { system })
}
