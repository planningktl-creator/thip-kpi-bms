import { createServer } from 'node:http';
import { existsSync, readFileSync } from 'node:fs';
import { resolve, extname, sep } from 'node:path';
const root = resolve('dist');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.json': 'application/json', '.svg': 'image/svg+xml' };
createServer((request, response) => {
  let path;
  try { path = resolve(root, `.${decodeURIComponent(new URL(request.url, 'http://localhost').pathname)}`); }
  catch { response.writeHead(400).end(); return; }
  if (!path.startsWith(root + sep) && path !== root) { response.writeHead(403).end(); return; }
  if (path === root || !extname(path)) path = resolve(root, 'index.html');
  if (!existsSync(path)) { response.writeHead(404).end(); return; }
  const compressed = /\bgzip\b/.test(request.headers['accept-encoding'] ?? '') && existsSync(path + '.gz');
  response.writeHead(200, {
    'Content-Type': types[extname(path)] ?? 'application/octet-stream',
    'Cache-Control': path.endsWith('index.html') ? 'no-cache, no-store, must-revalidate' : 'public, max-age=31536000, immutable',
    'Vary': 'Accept-Encoding', ...(compressed ? { 'Content-Encoding': 'gzip' } : {}),
  });
  response.end(readFileSync(path + (compressed ? '.gz' : '')));
}).listen(5186, '127.0.0.1', () => console.log('Performance fixture server: http://127.0.0.1:5186'));
