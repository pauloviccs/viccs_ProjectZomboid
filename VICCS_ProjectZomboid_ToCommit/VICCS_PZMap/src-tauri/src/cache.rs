use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use serde::{Deserialize, Serialize};
use base64::{Engine as _, engine::general_purpose::STANDARD as BASE64};

#[derive(Debug, Serialize, Deserialize)]
pub struct CacheStats {
    pub total_tiles: usize,
    pub total_size_mb: f64,
    pub cache_path: String,
}

/// Retorna o diretório base para o cache de tiles no disco
pub fn get_cache_dir() -> PathBuf {
    let mut path = dirs::data_local_dir().unwrap_or_else(|| PathBuf::from("./"));
    path.push("VICCS_PZMap");
    path.push("cache");
    path.push("tiles");
    path
}

/// Garante que o diretório para um tile específico exista
fn ensure_tile_dir(path: &Path) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    Ok(())
}

/// Carrega ou baixa um tile isométrico original e retorna como Data URL Base64
pub async fn fetch_tile_cached(layer: &str, z: u32, x: u32, y: u32) -> Result<String, String> {
    let cache_dir = get_cache_dir();
    let is_layer_zero = layer == "0" || layer == "layer0";
    let ext = if is_layer_zero { "jpg" } else { "webp" };
    let mime = if is_layer_zero { "image/jpeg" } else { "image/webp" };

    let layer_name = if layer.starts_with("layer") {
        layer.to_string()
    } else {
        format!("layer{}", layer)
    };

    let tile_path = cache_dir.join(&layer_name).join(z.to_string()).join(format!("{}_{}.{}", x, y, ext));

    // 1. Se o tile já existe em disco, lê diretamente
    if tile_path.exists() {
        if let Ok(mut file) = File::open(&tile_path) {
            let mut buffer = Vec::new();
            if file.read_to_end(&mut buffer).is_ok() {
                let encoded = BASE64.encode(&buffer);
                return Ok(format!("data:{};base64,{}", mime, encoded));
            }
        }
    }

    // 2. Se não existe, faz download do CDN de alta performance oficial do PZMap (Build 42/41)
    let urls = vec![
        format!("https://tiles.pzmap.net/base/{}_files/{}/{}_{}.{}", layer_name, z, x, y, ext),
        format!("https://pzmap.net/tiles/{}_files/{}/{}_{}.{}", layer_name, z, x, y, ext),
    ];

    let client = reqwest::Client::builder()
        .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
        .build()
        .map_err(|e| e.to_string())?;

    for url in urls {
        match client.get(&url).header("Referer", "https://pzmap.net/").send().await {
            Ok(resp) if resp.status().is_success() => {
                if let Ok(bytes) = resp.bytes().await {
                    let bytes_vec = bytes.to_vec();

                    // Salva em cache de disco local para uso 100% offline futuro
                    if ensure_tile_dir(&tile_path).is_ok() {
                        if let Ok(mut file) = File::create(&tile_path) {
                            let _ = file.write_all(&bytes_vec);
                        }
                    }

                    let encoded = BASE64.encode(&bytes_vec);
                    return Ok(format!("data:{};base64,{}", mime, encoded));
                }
            }
            _ => continue,
        }
    }

    Err(format!("Tile {}/{}/{}_{} indisponível", layer, z, x, y))
}

/// Calcula estatísticas do cache de tiles em disco
pub fn calculate_cache_stats() -> CacheStats {
    let cache_dir = get_cache_dir();
    let mut total_tiles = 0;
    let mut total_bytes: u64 = 0;

    fn visit_dir(dir: &Path, count: &mut usize, bytes: &mut u64) {
        if let Ok(entries) = fs::read_dir(dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    visit_dir(&path, count, bytes);
                } else {
                    let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
                    if ext == "jpg" || ext == "jpeg" || ext == "webp" || ext == "png" {
                        *count += 1;
                        if let Ok(meta) = entry.metadata() {
                            *bytes += meta.len();
                        }
                    }
                }
            }
        }
    }

    if cache_dir.exists() {
        visit_dir(&cache_dir, &mut total_tiles, &mut total_bytes);
    }

    let total_size_mb = (total_bytes as f64) / (1024.0 * 1024.0);
    CacheStats {
        total_tiles,
        total_size_mb: (total_size_mb * 100.0).round() / 100.0,
        cache_path: cache_dir.to_string_lossy().to_string(),
    }
}

/// Limpa todo o cache de tiles
pub fn clear_cache() -> Result<(), String> {
    let cache_dir = get_cache_dir();
    if cache_dir.exists() {
        fs::remove_dir_all(&cache_dir).map_err(|e| e.to_string())?;
    }
    Ok(())
}
