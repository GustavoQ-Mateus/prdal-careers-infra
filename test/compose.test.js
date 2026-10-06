const assert = require('node:assert/strict');
const test = require('node:test');
const { readFileSync } = require('node:fs');
const path = require('node:path');

const compose = readFileSync(path.resolve(__dirname, '../docker-compose.yml'), 'utf8').replace(/\r\n/g, '\n');

test('compose roda a migracao num passo proprio antes da api', () => {
  assert.match(compose, /migracao:\n(?:.*\n)*?\s+command: \["npx", "prisma", "migrate", "deploy"\]/);
  assert.match(compose, /migracao:\n\s+condition: service_completed_successfully/);
});

test('compose usa postgres e contextos proprios sem mongo nem chroma', () => {
  assert.doesNotMatch(compose, /mongo|chroma/i);
  assert.match(compose, /context: \.\/postgres/);
  assert.doesNotMatch(compose, /context: \.\.\s*\n/);
  assert.match(compose, /context: \.\.\/apps\/api/);
});
