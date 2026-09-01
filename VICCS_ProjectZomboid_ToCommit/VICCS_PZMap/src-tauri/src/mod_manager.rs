use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::Duration;
use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocalModInfo {
    pub id: String,
    pub name: String,
    pub description: String,
    pub version_min: Option<String>,
    pub poster_base64: Option<String>,
    pub icon_base64: Option<String>,
    pub source_type: String, // "local" | "workshop"
    pub folder_path: String,
    pub workshop_id: Option<String>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModItem {
    pub id: String,
    pub name: String,
    #[serde(default = "default_mod_type")]
    pub mod_type: String, // "builtin" | "workshop" | "direct_download"
    pub workshop_id: Option<String>,
    pub download_url: Option<String>,
    pub folder_name: Option<String>,
    pub version: Option<String>,
    #[serde(default)]
    pub required: bool,
    pub description: Option<String>,
}

fn default_mod_type() -> String {
    "workshop".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModpackManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub author: String,
    pub description: String,
    pub image: Option<String>,
    pub zomboid_version: Option<String>,
    pub updated_at: Option<String>,
    pub source_url: Option<String>,
    #[serde(default)]
    pub mods: Vec<ModItem>,
}

/// Retorna o caminho da pasta Zomboid/mods do usuário
pub fn get_zomboid_mods_dir() -> PathBuf {
    let mut path = dirs::home_dir().unwrap_or_else(|| PathBuf::from("./"));
    path.push("Zomboid");
    path.push("mods");
    path
}

/// Retorna possíveis caminhos da pasta do Workshop do Project Zomboid (App ID: 108600)
pub fn get_steam_workshop_dirs() -> Vec<PathBuf> {
    let mut dirs_list = Vec::new();
    
    // Caminhos padrões conhecidos no Windows
    let candidates = [
        r"C:\Program Files (x86)\Steam\steamapps\workshop\content\108600",
        r"C:\Program Files\Steam\steamapps\workshop\content\108600",
        r"D:\SteamLibrary\steamapps\workshop\content\108600",
        r"D:\Steam\steamapps\workshop\content\108600",
        r"E:\SteamLibrary\steamapps\workshop\content\108600",
        r"E:\Steam\steamapps\workshop\content\108600",
        r"F:\SteamLibrary\steamapps\workshop\content\108600",
        r"G:\SteamLibrary\steamapps\workshop\content\108600",
    ];

    for c in candidates {
        let p = PathBuf::from(c);
        if p.exists() && p.is_dir() {
            dirs_list.push(p);
        }
    }

    dirs_list
}

/// Lê arquivo de imagem pequeno e converte em Data URI Base64
fn read_image_to_base64(path: &Path) -> Option<String> {
    if !path.exists() {
        return None;
    }
    if let Ok(metadata) = fs::metadata(path) {
        if metadata.len() > 1_500_000 {
            return None; // Evita carregar imagens gigantes
        }
    }
    if let Ok(mut file) = File::open(path) {
        let mut buffer = Vec::new();
        if file.read_to_end(&mut buffer).is_ok() {
            let encoded = BASE64.encode(&buffer);
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("png").to_lowercase();
            let mime = if ext == "jpg" || ext == "jpeg" { "image/jpeg" } else { "image/png" };
            return Some(format!("data:{};base64,{}", mime, encoded));
        }
    }
    None
}

/// Faz parsing linha por linha do formato mod.info do Project Zomboid
fn parse_mod_info(mod_info_path: &Path, source_type: &str, workshop_id: Option<String>) -> Option<LocalModInfo> {
    if !mod_info_path.exists() {
        return None;
    }
    let content = fs::read_to_string(mod_info_path).ok()?;
    let parent_dir = mod_info_path.parent().unwrap_or(Path::new(""));

    let mut id = String::new();
    let mut name = String::new();
    let mut description = String::new();
    let mut version_min = None;
    let mut poster_filename = None;
    let mut icon_filename = None;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        if let Some((k, v)) = line.split_once('=') {
            let key = k.trim().to_lowercase();
            let val = v.trim().to_string();

            match key.as_str() {
                "id" => id = val,
                "name" => name = val,
                "description" => description = val,
                "versionmin" => version_min = Some(val),
                "poster" => poster_filename = Some(val),
                "icon" => icon_filename = Some(val),
                _ => {}
            }
        }
    }

    if id.is_empty() {
        // Fallback: se não tiver id, usa o nome da pasta
        id = parent_dir.file_name().and_then(|n| n.to_str()).unwrap_or("unknown").to_string();
    }
    if name.is_empty() {
        name = id.clone();
    }

    // Procura poster
    let poster_path = if let Some(ref p_file) = poster_filename {
        parent_dir.join(p_file)
    } else {
        parent_dir.join("poster.png")
    };
    let poster_base64 = read_image_to_base64(&poster_path);

    // Procura icon
    let icon_path = if let Some(ref i_file) = icon_filename {
        parent_dir.join(i_file)
    } else {
        parent_dir.join("icon.png")
    };
    let icon_base64 = read_image_to_base64(&icon_path);

    Some(LocalModInfo {
        id,
        name,
        description,
        version_min,
        poster_base64,
        icon_base64,
        source_type: source_type.to_string(),
        folder_path: parent_dir.to_string_lossy().to_string(),
        workshop_id,
        is_active: true,
    })
}

/// Varre pastas recursivamente buscando arquivos mod.info
fn scan_folder_for_mods(base_path: &Path, source_type: &str, workshop_id: Option<String>, results: &mut Vec<LocalModInfo>) {
    if !base_path.exists() || !base_path.is_dir() {
        return;
    }

    let direct_mod_info = base_path.join("mod.info");
    if direct_mod_info.exists() {
        if let Some(mod_info) = parse_mod_info(&direct_mod_info, source_type, workshop_id.clone()) {
            results.push(mod_info);
            return;
        }
    }

    // Se a pasta for uma pasta pai (ex: Zomboid/mods ou uma pasta de workshop com sub-mods)
    if let Ok(entries) = fs::read_dir(base_path) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                let sub_mod_info = path.join("mod.info");
                if sub_mod_info.exists() {
                    let w_id = if source_type == "workshop" && workshop_id.is_none() {
                        base_path.file_name().and_then(|n| n.to_str()).map(|s| s.to_string())
                    } else {
                        workshop_id.clone()
                    };
                    if let Some(mod_info) = parse_mod_info(&sub_mod_info, source_type, w_id) {
                        results.push(mod_info);
                    }
                } else {
                    // Verifica subpastas com mods aninhados (como mods/42/ ou mods/common/)
                    if let Ok(sub_entries) = fs::read_dir(&path) {
                        for sub_entry in sub_entries.flatten() {
                            let sub_path = sub_entry.path();
                            if sub_path.is_dir() {
                                let nested_mod_info = sub_path.join("mod.info");
                                if nested_mod_info.exists() {
                                    if let Some(mod_info) = parse_mod_info(&nested_mod_info, source_type, workshop_id.clone()) {
                                        results.push(mod_info);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Varre todos os mods instalados localmente (%USERPROFILE%/Zomboid/mods e Steam Workshop)
pub fn scan_all_installed_mods() -> Vec<LocalModInfo> {
    let mut mods = Vec::new();

    // 1. Varre a pasta local do usuário
    let user_mods_dir = get_zomboid_mods_dir();
    scan_folder_for_mods(&user_mods_dir, "local", None, &mut mods);

    // 2. Varre as pastas de Workshop da Steam detectadas
    let workshop_dirs = get_steam_workshop_dirs();
    for ws_dir in workshop_dirs {
        if let Ok(entries) = fs::read_dir(&ws_dir) {
            for entry in entries.flatten() {
                let item_dir = entry.path();
                if item_dir.is_dir() {
                    let w_id = item_dir.file_name().and_then(|n| n.to_str()).map(|s| s.to_string());
                    scan_folder_for_mods(&item_dir, "workshop", w_id, &mut mods);
                }
            }
        }
    }

    // Remove duplicatas de ID priorizando mod local sobre workshop
    let mut unique_mods: Vec<LocalModInfo> = Vec::new();
    for m in mods {
        if !unique_mods.iter().any(|existing| existing.id.eq_ignore_ascii_case(&m.id)) {
            unique_mods.push(m);
        }
    }

    // Ordena por nome alfabético
    unique_mods.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    unique_mods
}

/// Normaliza uma URL do Pastebin para seu formato RAW
pub fn normalize_pastebin_url(url: &str) -> String {
    let trimmed = url.trim();
    if trimmed.contains("pastebin.com/") && !trimmed.contains("pastebin.com/raw/") {
        if let Some(id) = trimmed.split("pastebin.com/").nth(1) {
            let clean_id = id.trim_matches('/');
            return format!("https://pastebin.com/raw/{}", clean_id);
        }
    }
    trimmed.to_string()
}

/// Busca manifesto de modpack remoto via Pastebin ou URL JSON direta
pub async fn fetch_modpack_manifest(url: String) -> Result<ModpackManifest, String> {
    let final_url = normalize_pastebin_url(&url);

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(12))
        .user_agent("PZHub-ModManager/2.0")
        .build()
        .map_err(|e| format!("Erro ao inicializar cliente HTTP: {}", e))?;

    let response = client
        .get(&final_url)
        .send()
        .await
        .map_err(|e| format!("Falha de conexão ao buscar manifesto: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("O servidor retornou status HTTP {}", response.status()));
    }

    let text = response
        .text()
        .await
        .map_err(|e| format!("Falha ao ler conteúdo do manifesto: {}", e))?;

    let mut manifest: ModpackManifest = serde_json::from_str(&text)
        .map_err(|e| format!("O arquivo retornado não é um manifesto JSON de modpack válido: {}", e))?;

    manifest.source_url = Some(url);
    Ok(manifest)
}

/// Baixa arquivo ZIP direto e extrai em %USERPROFILE%/Zomboid/mods/<folder_name>
pub async fn download_and_extract_direct_mod(download_url: String, folder_name: String) -> Result<String, String> {
    let mods_dir = get_zomboid_mods_dir();
    fs::create_dir_all(&mods_dir).map_err(|e| format!("Erro ao criar pasta mods: {}", e))?;

    let target_folder = mods_dir.join(&folder_name);
    let temp_zip_path = mods_dir.join(format!(".temp_download_{}.zip", folder_name));

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(60))
        .user_agent("PZHub-Downloader/2.0")
        .build()
        .map_err(|e| format!("Erro no cliente HTTP: {}", e))?;

    let response = client
        .get(&download_url)
        .send()
        .await
        .map_err(|e| format!("Erro ao conectar com link de download: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("Erro no download: HTTP {}", response.status()));
    }

    let bytes = response
        .bytes()
        .await
        .map_err(|e| format!("Erro ao receber dados do mod: {}", e))?;

    fs::write(&temp_zip_path, &bytes)
        .map_err(|e| format!("Erro ao salvar arquivo temporário do mod: {}", e))?;

    // Cria a pasta de destino se não existir
    let _ = fs::create_dir_all(&target_folder);

    // Extrai no Windows via PowerShell com segurança e overwrite forçado
    let ps_script = format!(
        "Expand-Archive -LiteralPath '{}' -DestinationPath '{}' -Force",
        temp_zip_path.to_string_lossy(),
        target_folder.to_string_lossy()
    );

    let output = Command::new("powershell")
        .args(["-NoProfile", "-Command", &ps_script])
        .output()
        .map_err(|e| format!("Erro ao executar extração do zip: {}", e))?;

    // Remove o zip temporário
    let _ = fs::remove_file(&temp_zip_path);

    if !output.status.success() {
        let err_msg = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Erro durante a extração: {}", err_msg));
    }

    Ok(target_folder.to_string_lossy().to_string())
}

/// Abre item do Steam Workshop no cliente Steam ou no navegador padrão
pub fn open_steam_workshop(workshop_id: &str) -> Result<(), String> {
    let steam_protocol = format!("steam://url/CommunityFilePage/{}", workshop_id);
    let browser_url = format!("https://steamcommunity.com/sharedfiles/filedetails/?id={}", workshop_id);

    #[cfg(target_os = "windows")]
    {
        // Tenta abrir com protocolo Steam
        let status = Command::new("cmd")
            .args(["/c", "start", &steam_protocol])
            .spawn();

        if status.is_err() {
            // Fallback para navegador
            let _ = Command::new("cmd")
                .args(["/c", "start", &browser_url])
                .spawn();
        }
    }

    Ok(())
}

/// Abre uma pasta no Windows Explorer
pub fn open_folder(folder_path: &str) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        let _ = Command::new("explorer")
            .arg(folder_path)
            .spawn()
            .map_err(|e| format!("Erro ao abrir pasta: {}", e))?;
    }
    Ok(())
}
