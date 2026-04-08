use serde_json::json;
use socketioxide::extract::{Data, SocketRef};
use socketioxide::SocketIo;
use std::sync::Arc;
use tokio::sync::broadcast;

/// Events emitted to all clients
#[derive(Clone)]
pub struct EventEmitter {
    tx: broadcast::Sender<SocketEvent>,
}

#[derive(Clone, Debug)]
pub enum SocketEvent {
    StreamChunk { conversation_id: String, message_id: String, delta: String },
    StreamDone { conversation_id: String, message_id: String, content: String, tokens_used: Option<u32> },
    StreamError { conversation_id: String, error: String },
    CronFired { cron_id: String, name: String },
    FlowUpdate { flow_id: String, run_id: String, status: String },
}

impl EventEmitter {
    pub fn new() -> (Self, broadcast::Receiver<SocketEvent>) {
        let (tx, rx) = broadcast::channel(256);
        (Self { tx }, rx)
    }

    pub fn emit_stream_chunk(&self, conversation_id: &str, message_id: &str, delta: &str) {
        let _ = self.tx.send(SocketEvent::StreamChunk {
            conversation_id: conversation_id.to_string(),
            message_id: message_id.to_string(),
            delta: delta.to_string(),
        });
    }

    pub fn emit_stream_done(&self, conversation_id: &str, message_id: &str, content: &str, tokens: Option<u32>) {
        let _ = self.tx.send(SocketEvent::StreamDone {
            conversation_id: conversation_id.to_string(),
            message_id: message_id.to_string(),
            content: content.to_string(),
            tokens_used: tokens,
        });
    }

    pub fn emit_stream_error(&self, conversation_id: &str, error: &str) {
        let _ = self.tx.send(SocketEvent::StreamError {
            conversation_id: conversation_id.to_string(),
            error: error.to_string(),
        });
    }

    pub fn emit_cron_fired(&self, cron_id: &str, name: &str) {
        let _ = self.tx.send(SocketEvent::CronFired {
            cron_id: cron_id.to_string(),
            name: name.to_string(),
        });
    }

    pub fn emit_flow_update(&self, flow_id: &str, run_id: &str, status: &str) {
        let _ = self.tx.send(SocketEvent::FlowUpdate {
            flow_id: flow_id.to_string(),
            run_id: run_id.to_string(),
            status: status.to_string(),
        });
    }
}

pub fn setup_socket(io: &SocketIo, mut rx: broadcast::Receiver<SocketEvent>) {
    // Forward broadcast events to all connected sockets
    let io_clone = io.clone();
    tokio::spawn(async move {
        while let Ok(event) = rx.recv().await {
            match &event {
                SocketEvent::StreamChunk { conversation_id, message_id, delta } => {
                    let _ = io_clone.emit("stream:chunk", json!({
                        "conversationId": conversation_id,
                        "messageId": message_id,
                        "delta": delta,
                    }));
                }
                SocketEvent::StreamDone { conversation_id, message_id, content, tokens_used } => {
                    let _ = io_clone.emit("stream:done", json!({
                        "conversationId": conversation_id,
                        "messageId": message_id,
                        "content": content,
                        "tokensUsed": tokens_used,
                    }));
                }
                SocketEvent::StreamError { conversation_id, error } => {
                    let _ = io_clone.emit("stream:error", json!({
                        "conversationId": conversation_id,
                        "error": error,
                    }));
                }
                SocketEvent::CronFired { cron_id, name } => {
                    let _ = io_clone.emit("cron:fired", json!({
                        "cronId": cron_id,
                        "name": name,
                    }));
                }
                SocketEvent::FlowUpdate { flow_id, run_id, status } => {
                    let _ = io_clone.emit("flow:update", json!({
                        "flowId": flow_id,
                        "runId": run_id,
                        "status": status,
                    }));
                }
            }
        }
    });

    io.ns("/", |socket: SocketRef| {
        tracing::info!("Socket connected: {}", socket.id);

        socket.on_disconnect(|s: SocketRef| {
            tracing::info!("Socket disconnected: {}", s.id);
        });
    });
}
