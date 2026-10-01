import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { gzipSync } from 'node:zlib';
function compress(dir) {
  for (const item of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, item.name);
    if (item.isDirectory()) compress(path);
    else if (/\.(js|css|svg|html)$/.test(path)) writeFileSync(`${path}.gz`, gzipSync(readFileSync(path), { level: 9 }));
  }
}
compress('dist');
console.log('Precompressed production text assets');
