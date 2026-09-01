use serde::{Deserialize, Serialize};
use std::fs;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayerTelemetry {
    pub id: String,
    pub name: String,
    pub steam_id: String,
    pub x: f64,
    pub y: f64,
    pub z: i32,
    pub health: f32,
    pub faction: String,
    pub is_alive: bool,
    pub is_self: bool,
    #[serde(default)]
    pub last_seen: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SquadState {
    pub server_name: String,
    pub is_connected: bool,
    pub players: Vec<PlayerTelemetry>,
    #[serde(default)]
    pub timestamp: u64,
    #[serde(default)]
    pub source: String, // "live_game" ou "offline"
}

pub struct TelemetryManager {
    pub is_simulating: Arc<AtomicBool>,
}

impl TelemetryManager {
    pub fn new() -> Self {
        Self {
            is_simulating: Arc::new(AtomicBool::new(false)),
        }
    }
}

fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}

/// Tenta ler os dados reais gravados pelo Mod Lua em Zomboid/Lua/viccs_telemetry.json
pub fn read_live_telemetry() -> Option<SquadState> {
    let mut path = dirs::home_dir()?;
    path.push("Zomboid");
    path.push("Lua");
    path.push("viccs_telemetry.json");

    if !path.exists() {
        return None;
    }

    let metadata = fs::metadata(&path).ok()?;
    let modified = metadata.modified().ok()?;
    let elapsed = modified.elapsed().ok()?;

    // Considera ativo se o arquivo foi modificado nos últimos 8 segundos
    if elapsed.as_secs() > 8 {
        return None;
    }

    let content = fs::read_to_string(&path).ok()?;
    let mut state: SquadState = serde_json::from_str(&content).ok()?;
    state.source = "live_game".to_string();
    state.is_connected = true;
    if state.timestamp == 0 {
        state.timestamp = current_timestamp();
    }
    Some(state)
}

/// Retorna estado offline limpo (zero jogadores falsos)
pub fn get_offline_state() -> SquadState {
    SquadState {
        server_name: "Aguardando Project Zomboid".to_string(),
        is_connected: false,
        players: vec![],
        timestamp: current_timestamp(),
        source: "offline".to_string(),
    }
}
