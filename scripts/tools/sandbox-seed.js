'use strict';
// Standalone seed CLI for the /sandbox --seed action — deliberately independent of
// br-tax-engine's own test/_tools/seed-local-db.js (a personal, unused-by-the-team script the
// user may delete or rewrite) so that file's fate never affects /sandbox. Still depends on
// test/_database/index.js (br-tax-engine's own integration-test seeding module -- it mirrors
// what the integration tests' own `before` hooks do) and, transitively, test/_helpers/
// storage-helper.js -- those are stable, team-owned test infrastructure, not slated for removal,
// and reimplementing them independently would mean duplicating hundreds of lines of citation/
// company/tax fixture-loading logic that's already correct. DB_NAME override is handled by the
// caller (sandbox.sh) via the NODE_OPTIONS preload, same mechanism as engine/ui-proxy -- this
// script has no DB_NAME logic of its own.
//
// Usage: node sandbox-seed.js <br-tax-engine-dir> [--version <2|3|all>] [--goods] [--no-goods]
//                              [--services] [--no-services] [--invoice]

const path = require('path');

const engineDir = process.argv[2];
if (!engineDir) {
   console.error('Usage: node sandbox-seed.js <br-tax-engine-dir> [flags]');
   process.exit(2);
}

if (!process.env.NODE_ENV) {
   process.env.NODE_ENV = 'test';
}

function parseArgs(argv) {
   const opts = { goods: true, services: true, invoice: false, version: 3 };
   for (let i = 0; i < argv.length; i++) {
      switch (argv[i]) {
         case '--version':
            opts.version = normalizeVersion(argv[++i]);
            break;
         case '--goods':
            opts.goods = true;
            break;
         case '--no-goods':
            opts.goods = false;
            break;
         case '--services':
            opts.services = true;
            break;
         case '--no-services':
            opts.services = false;
            break;
         case '--invoice':
            opts.invoice = true;
            break;
         default:
            break;
      }
   }
   return opts;
}

function normalizeVersion(value) {
   if ('all' === value) return 'all';
   const parsed = Number(value);
   return Number.isNaN(parsed) ? 3 : parsed;
}

const database = require(path.join(engineDir, 'test', '_database'));

(async () => {
   const opts = parseArgs(process.argv.slice(3));
   console.log(`[sandbox-seed] Seeding with: ${JSON.stringify(opts)}`);
   const start = Date.now();
   await database(opts);
   console.log(
      `[sandbox-seed] Seed completed in ${((Date.now() - start) / 1000).toFixed(1)}s`
   );
   process.exit(0);
})().catch(err => {
   console.error('[sandbox-seed] Seed failed:', err);
   process.exit(1);
});
