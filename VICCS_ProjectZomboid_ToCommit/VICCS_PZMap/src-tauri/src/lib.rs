pub mod cache;
pub mod tracker;
pub mod config;
pub mod mod_installer;
pub mod mod_manager;

use tauri::Manager;
use cache::{fetch_tile_cached, calculate_cache_stats, clear_cache, CacheStats};
use tracker::{read_live_telemetry, get_offline_state, SquadState};
use config::{load_config, save_config, UserConfig, FriendEntry};
use mod_installer::{install_mod, open_mods_folder};
use mod_manager::{
    scan_all_installed_mods, fetch_modpack_manifest, download_and_extract_direct_mod,
    open_steam_workshop, open_folder, LocalModInfo, ModpackManifest,
};

#[tauri::command]
async fn get_tile(layer: String, z: u32, x: u32, y: u32) -> Result<String, String> {
    fetch_tile_cached(&layer, z, x, y).await
}

#[tauri::command]
fn get_cache_stats() -> CacheStats {
    calculate_cache_stats()
}

#[tauri::command]
fn clear_tile_cache() -> Result<(), String> {
    clear_cache()
}

#[tauri::command]
fn get_squad_telemetry(_step: u64) -> SquadState {
    if let Some(live_state) = read_live_telemetry() {
        return live_state;
    }
    get_offline_state()
}

#[tauri::command]
fn get_user_config() -> UserConfig {
    load_config()
}

#[tauri::command]
fn set_user_config(config: UserConfig) -> Result<(), String> {
    save_config(&config)
}

#[tauri::command]
fn get_friends() -> Vec<FriendEntry> {
    let cfg = load_config();
    cfg.friends
}

#[tauri::command]
fn add_friend(friend: FriendEntry) -> Result<Vec<FriendEntry>, String> {
    let mut cfg = load_config();
    cfg.friends.retain(|f| !f.username.eq_ignore_ascii_case(&friend.username));
    cfg.friends.push(friend);
    save_config(&cfg)?;
    Ok(cfg.friends)
}

#[tauri::command]
fn remove_friend(username: String) -> Result<Vec<FriendEntry>, String> {
    let mut cfg = load_config();
    cfg.friends.retain(|f| !f.username.eq_ignore_ascii_case(&username));
    save_config(&cfg)?;
    Ok(cfg.friends)
}

#[tauri::command]
fn scan_installed_mods() -> Vec<LocalModInfo> {
    scan_all_installed_mods()
}

#[tauri::command]
async fn fetch_remote_modpack(url: String) -> Result<ModpackManifest, String> {
    fetch_modpack_manifest(url).await
}

#[tauri::command]
async fn download_and_extract_mod(download_url: String, folder_name: String) -> Result<String, String> {
    download_and_extract_direct_mod(download_url, folder_name).await
}

#[tauri::command]
fn open_steam_workshop_item(workshop_id: String) -> Result<(), String> {
    open_steam_workshop(&workshop_id)
}

#[tauri::command]
fn open_mod_folder(folder_path: String) -> Result<(), String> {
    open_folder(&folder_path)
}

#[tauri::command]
fn save_modpack(manifest: ModpackManifest) -> Result<Vec<ModpackManifest>, String> {
    let mut cfg = load_config();
    cfg.saved_modpacks.retain(|m| !m.id.eq_ignore_ascii_case(&manifest.id));
    cfg.saved_modpacks.push(manifest);
    save_config(&cfg)?;
    Ok(cfg.saved_modpacks)
}

#[tauri::command]
fn remove_saved_modpack(modpack_id: String) -> Result<Vec<ModpackManifest>, String> {
    let mut cfg = load_config();
    cfg.saved_modpacks.retain(|m| !m.id.eq_ignore_ascii_case(&modpack_id));
    save_config(&cfg)?;
    Ok(cfg.saved_modpacks)
}

#[tauri::command]
fn set_always_on_top(app: tauri::AppHandle, enabled: bool) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("main") {
        window.set_always_on_top(enabled).map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn set_mini_radar_mode(app: tauri::AppHandle, enabled: bool) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("main") {
        if enabled {
            // Remove a barra de títulos e bordas nativas do Windows no modo mini radar
            let _ = window.set_decorations(false);

            // Modo Mini-Radar GTA V: Formato retangular widescreen (340x220px) no canto inferior esquerdo
            let size = tauri::LogicalSize::new(340.0, 220.0);
            let _ = window.set_size(tauri::Size::Logical(size));
            let _ = window.set_always_on_top(true);

            // Posiciona no canto inferior esquerdo da tela atual do usuário
            if let Ok(Some(monitor)) = window.current_monitor() {
                let monitor_size = monitor.size();
                let scale_factor = monitor.scale_factor();
                let logical_h = monitor_size.height as f64 / scale_factor;
                let target_x = 30.0;
                let target_y = (logical_h - 260.0).max(40.0);
                let _ = window.set_position(tauri::Position::Logical(tauri::LogicalPosition::new(target_x, target_y)));
            }
        } else {
            // Restaura as decorações e barra nativa do Windows no modo tela cheia
            let _ = window.set_decorations(true);

            // Modo Mapa Completo: Restaura tamanho original 1280x820 e centraliza
            let size = tauri::LogicalSize::new(1280.0, 820.0);
            let _ = window.set_size(tauri::Size::Logical(size));
            let _ = window.center();
        }
    }
    Ok(())
}

#[tauri::command]
fn minimize_window(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("main") {
        window.minimize().map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn close_window(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(window) = app.get_webview_window("main") {
        window.close().map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn install_zomboid_mod() -> Result<String, String> {
    install_mod()
}

#[tauri::command]
fn open_zomboid_mods_dir() -> Result<(), String> {
    open_mods_folder()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            get_tile,
            get_cache_stats,
            clear_tile_cache,
            get_squad_telemetry,
            get_user_config,
            set_user_config,
            get_friends,
            add_friend,
            remove_friend,
            scan_installed_mods,
            fetch_remote_modpack,
            download_and_extract_mod,
            open_steam_workshop_item,
            open_mod_folder,
            save_modpack,
            remove_saved_modpack,
            set_always_on_top,
            set_mini_radar_mode,
            minimize_window,
            close_window,
            install_zomboid_mod,
            open_zomboid_mods_dir
        ])
        .run(tauri::generate_context!())
        .expect("error while running PZHub tauri application");
}
