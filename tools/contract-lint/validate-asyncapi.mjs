// Validates an AsyncAPI document with the official parser; fails on any error diagnostic.
import { Parser } from '@asyncapi/parser';
import { readFileSync } from 'node:fs';
const file = process.argv[2];
const parser = new Parser();
const { document, diagnostics } = await parser.parse(readFileSync(file, 'utf8'));
const errors = diagnostics.filter(d => d.severity === 0);
for (const d of diagnostics) console.log(['ERROR','WARN','INFO','HINT'][d.severity], d.code, d.path.join('.'), '-', d.message);
if (!document || errors.length) { console.error(`FAIL: ${errors.length} error(s)`); process.exit(1); }
console.log(`OK: ${file} AsyncAPI ${document.version()}`);
