use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

// Embutição dos arquivos do mod diretamente no binário Rust para instalação 100% garantida
const MOD_INFO: &str = include_str!("../../server-mod/mod.info");
const MOD_README: &str = include_str!("../../server-mod/README.md");
const MOD_POSTER: &[u8] = include_bytes!("../../server-mod/poster.png");
const MOD_ICON: &[u8] = include_bytes!("../../server-mod/icon.png");
const CLIENT_LUA: &str = include_str!("../../server-mod/media/lua/client/VICCS_ClientTracker.lua");
const SERVER_LUA: &str = include_str!("../../server-mod/media/lua/server/VICCS_ServerTracker.lua");

/// Retorna o caminho da pasta Zomboid/mods no computador do usuário
pub fn get_zomboid_mods_dir() -> PathBuf {
    let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("./"));
    path.push("Zomboid");
    path.push("mods");
    path
}

fn write_mod_tree(base: &Path) -> Result<(), String> {
    let client_dir = base.join("media").join("lua").join("client");
    let server_dir = base.join("media").join("lua").join("server");

    fs::create_dir_all(&client_dir).map_err(|e| format!("Erro ao criar pasta client: {}", e))?;
    fs::create_dir_all(&server_dir).map_err(|e| format!("Erro ao criar pasta server: {}", e))?;

    fs::write(base.join("mod.info"), MOD_INFO)
        .map_err(|e| format!("Erro ao gravar mod.info: {}", e))?;

    fs::write(base.join("README.md"), MOD_README)
        .map_err(|e| format!("Erro ao gravar README.md: {}", e))?;

    fs::write(base.join("poster.png"), MOD_POSTER)
        .map_err(|e| format!("Erro ao gravar poster.png: {}", e))?;

    fs::write(base.join("icon.png"), MOD_ICON)
        .map_err(|e| format!("Erro ao gravar icon.png: {}", e))?;

    fs::write(client_dir.join("VICCS_ClientTracker.lua"), CLIENT_LUA)
        .map_err(|e| format!("Erro ao gravar script client: {}", e))?;

    fs::write(server_dir.join("VICCS_ServerTracker.lua"), SERVER_LUA)
        .map_err(|e| format!("Erro ao gravar script server: {}", e))?;

    Ok(())
}

/// Instala o mod diretamente na pasta de mods com compatibilidade integral com Project Zomboid Build 42
pub fn install_mod() -> Result<String, String> {
    let mods_dir = get_zomboid_mods_dir();
    let target_dir = mods_dir.join("VICCSRadarBridge");

    // 1. Grava na raiz do mod
    write_mod_tree(&target_dir)?;

    // 2. Grava na subpasta 42/ (formato específico do Project Zomboid Build 42)
    let b42_dir = target_dir.join("42");
    write_mod_tree(&b42_dir)?;

    // 3. Grava na subpasta 42.0/ (formato alternativo B42)
    let b42_0_dir = target_dir.join("42.0");
    write_mod_tree(&b42_0_dir)?;

    // 4. Grava na subpasta common/ (formato de mods universais B42)
    let common_dir = target_dir.join("common");
    write_mod_tree(&common_dir)?;

    Ok(target_dir.to_string_lossy().to_string())
}

/// Abre a pasta de mods do Zomboid no Windows Explorer
pub fn open_mods_folder() -> Result<(), String> {
    let mods_dir = get_zomboid_mods_dir();
    let _ = fs::create_dir_all(&mods_dir);

    #[cfg(target_os = "windows")]
    {
        Command::new("explorer")
            .arg(mods_dir)
            .spawn()
            .map_err(|e| format!("Erro ao abrir o Explorer: {}", e))?;
    }

    Ok(())
}
