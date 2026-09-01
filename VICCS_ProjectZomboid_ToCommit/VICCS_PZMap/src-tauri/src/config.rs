use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::PathBuf;
use crate::mod_manager::ModpackManifest;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FriendEntry {
    pub username: String,
    pub nickname: Option<String>,
    pub steam_id: Option<String>,
    pub color: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerEntry {
    pub name: String,
    pub address: String,
    pub port: u16,
    pub key: Option<String>,
    pub is_favorite: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserConfig {
    pub always_on_top: bool,
    pub opacity: f32,
    pub active_server: Option<String>,
    pub steam_id: String,
    pub follow_self: bool,
    pub auto_cache_tiles: bool,
    pub servers: Vec<ServerEntry>,
    #[serde(default)]
    pub friends: Vec<FriendEntry>,
    #[serde(default)]
    pub saved_modpack_urls: Vec<String>,
    #[serde(default)]
    pub saved_modpacks: Vec<ModpackManifest>,
    pub custom_steam_path: Option<String>,
    #[serde(default = "default_active_view")]
    pub active_view: String, // "hub", "modpacks", "local_mods", "map"
}

fn default_active_view() -> String {
    "hub".to_string()
}

impl Default for UserConfig {
    fn default() -> Self {
        Self {
            always_on_top: false,
            opacity: 1.0,
            active_server: None,
            steam_id: "".to_string(),
            follow_self: true,
            auto_cache_tiles: true,
            servers: vec![],
            friends: vec![],
            saved_modpack_urls: vec![],
            saved_modpacks: vec![],
            custom_steam_path: None,
            active_view: "hub".to_string(),
        }
    }
}

fn get_config_path() -> PathBuf {
    let mut path = dirs::data_local_dir().unwrap_or_else(|| PathBuf::from("./"));
    path.push("VICCS_PZMap");
    path.push("config.json");
    path
}

pub fn load_config() -> UserConfig {
    let path = get_config_path();
    if path.exists() {
        if let Ok(mut file) = File::open(&path) {
            let mut contents = String::new();
            if file.read_to_string(&mut contents).is_ok() {
                if let Ok(config) = serde_json::from_str::<UserConfig>(&contents) {
                    return config;
                }
            }
        }
    }
    UserConfig::default()
}

pub fn save_config(config: &UserConfig) -> Result<(), String> {
    let path = get_config_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::to_string_pretty(config).map_err(|e| e.to_string())?;
    let mut file = File::create(&path).map_err(|e| e.to_string())?;
    file.write_all(json.as_bytes()).map_err(|e| e.to_string())?;
    Ok(())
}
