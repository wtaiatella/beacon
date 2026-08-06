'use strict';
// Loaded via NODE_OPTIONS="--require <this file>" before br-tax-engine's or br-tax-ui's own
// entry point runs. Their env-setup.js does `Object.assign($env, pm2Cfg, pm2Env, {...})` on
// every boot, which unconditionally OVERWRITES process.env with pm2.config.js's values --
// so exporting SRV_PORT/DB_NAME etc. before `npm start` has no effect, they get clobbered
// right back. Mutating pm2.config.js's own exported `env` object here, before that Object.assign
// runs, means env-setup.js's later `require('../pm2.config')` returns this already-patched
// object from Node's module cache (same resolved path, same cache entry) -- so the merge
// naturally picks up the override instead of fighting it. See SKILL.md "Multi-workspace" section.
//
// Env in (set by sandbox.sh, not by the app):
//   SANDBOX_PM2_CONFIG   absolute path to the target repo's pm2.config.js
//   SANDBOX_ENV_OVERRIDES  JSON object of keys to overwrite in apps[0].env

const configPath = process.env.SANDBOX_PM2_CONFIG;
const overridesRaw = process.env.SANDBOX_ENV_OVERRIDES;
if (!configPath || !overridesRaw) return;

const overrides = JSON.parse(overridesRaw);
const resolved = require.resolve(configPath);
const cfg = require(resolved);
const app = (cfg.apps && cfg.apps[0]) || cfg;
app.env = app.env || {};
Object.assign(app.env, overrides);
