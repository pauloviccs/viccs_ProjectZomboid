import https from 'https';
import fs from 'fs';
import path from 'path';

const files = [
  { url: 'https://pzmap.net/data/meta.json', dest: 'src/data/meta.json' },
  { url: 'https://pzmap.net/data/worldmap_water.json', dest: 'src/data/worldmap_water.json' },
  { url: 'https://pzmap.net/data/worldmap_forest.json', dest: 'src/data/worldmap_forest.json' },
  { url: 'https://pzmap.net/data/streets.json', dest: 'src/data/streets.json' },
  { url: 'https://pzmap.net/data/buildings_index.json', dest: 'src/data/buildings_index.json' }
];

fs.mkdirSync('src/data', { recursive: true });

async function download(item) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(item.dest);
    https.get(item.url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Referer': 'https://pzmap.net/web/'
      }
    }, (res) => {
      if (res.statusCode !== 200) {
        return reject(`Failed ${item.url}: ${res.statusCode}`);
      }
      res.pipe(file);
      file.on('finish', () => {
        file.close();
        console.log(`[DOWNLOADED] ${item.dest} (${fs.statSync(item.dest).size} bytes)`);
        resolve();
      });
    }).on('error', reject);
  });
}

async function main() {
  for (const f of files) {
    try {
      await download(f);
    } catch (e) {
      console.error(e);
    }
  }
}

main();
