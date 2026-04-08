use std::{fs, io::Write, net::TcpStream};
use rand::Rng;

fn main() -> anyhow::Result<()> {
    println!("\n  Hermes Server Setup\n  ==================\n");

    // Generate secrets
    let jwt_secret = hex::encode(rand::thread_rng().gen::<[u8; 32]>());
    let enc_key = hex::encode(rand::thread_rng().gen::<[u8; 32]>());

    // Detect public IP
    let public_ip = detect_ip();

    let port = std::env::var("PORT").unwrap_or_else(|_| "3001".to_string());

    // Write .env
    let env_content = format!(
        r#"PORT={port}
DATABASE_URL=sqlite://hermes.db
JWT_SECRET={jwt_secret}
ENCRYPTION_KEY={enc_key}

# Add your AI provider keys below:
# ANTHROPIC_API_KEY=your_key_here
# OPENAI_API_KEY=your_key_here
# GOOGLE_API_KEY=your_key_here
# MINIMAX_API_KEY=your_key_here
# OLLAMA_BASE_URL=http://localhost:11434
"#
    );

    fs::write(".env", &env_content)?;
    println!("  ✓ Generated secrets");
    println!("  ✓ Wrote .env");

    // Generate a connection token (signed JWT) using the new secret
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs() as usize;

    let claims = serde_json::json!({
        "sub": "setup",
        "email": "admin@hermes.local",
        "tier": "free",
        "iat": now,
        "exp": now + 60 * 60 * 24 * 365 * 10  // 10-year token for VPS connection
    });

    let token = jsonwebtoken::encode(
        &jsonwebtoken::Header::default(),
        &claims,
        &jsonwebtoken::EncodingKey::from_secret(jwt_secret.as_bytes()),
    )?;

    let server_url = format!("http://{}:{}", public_ip, port);

    println!("  ✓ Database will initialize on first start\n");
    println!("  ┌─────────────────────────────────────────────");
    println!("  │  Your Hermes server is ready!");
    println!("  │");
    println!("  │  Open the Hermes app → Settings → Connect Server");
    println!("  │");
    println!("  │  Server URL:  {}", server_url);
    println!("  │  Token:       {}...", &token[..40]);
    println!("  │");
    println!("  │  Full token (copy this into the app):");
    println!("  │  {}", token);
    println!("  └─────────────────────────────────────────────");

    // Print QR code to terminal
    println!("\n  Scan to connect:\n");
    let connect_payload = format!("{}\n{}", server_url, token);
    if let Ok(code) = qrcode::QrCode::new(connect_payload.as_bytes()) {
        let image = code.render::<char>()
            .quiet_zone(false)
            .module_dimensions(2, 1)
            .build();
        for line in image.lines() {
            println!("  {}", line);
        }
    }

    println!("\n  Run: hermes-server start\n");
    Ok(())
}

fn detect_ip() -> String {
    // Try to get public IP by connecting to a known host
    if let Ok(stream) = TcpStream::connect("8.8.8.8:80") {
        if let Ok(addr) = stream.local_addr() {
            return addr.ip().to_string();
        }
    }
    "127.0.0.1".to_string()
}
