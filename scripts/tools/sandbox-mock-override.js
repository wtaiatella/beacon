'use strict';

// Loaded only by the long-running sandbox mock. Product tests do not load this file.
//
// mock-servers.js hardcodes `const port = 3888` and then overwrites process.env.SERVER_PORT,
// so the SERVER_PORT exported by sandbox.sh never reaches listen() — the process tries the
// npm-test ports :3888/:3889, hits EADDRINUSE, and the workspace port stays closed.
// Capture SERVER_PORT before that assignment and rebind only those two reserved ports.

const reservedHttpPort = 3888;
const workspaceHttpPort = Number(process.env.SERVER_PORT);
if (workspaceHttpPort && workspaceHttpPort !== reservedHttpPort) {
   const net = require('net');
   const listen = net.Server.prototype.listen;
   net.Server.prototype.listen = function (port, ...args) {
      const requested = Number(port);
      if (requested === reservedHttpPort) port = workspaceHttpPort;
      else if (requested === reservedHttpPort + 1) port = workspaceHttpPort + 1;
      return listen.call(this, port, ...args);
   };
}

// The mock's password-flow fallback is a legacy opaque access token, while the current engine
// accepts compact JWE tokens. Replace that fallback in Node's module cache with the fixture's
// existing long-lived JWE before the OAuth router loads.

const fixturePath = process.env.SANDBOX_OAUTH_TOKEN_FIXTURE;
if (!fixturePath) return;

const tokens = require(require.resolve(fixturePath));
if (!tokens.token_unlimited) {
   throw new Error(
      `Sandbox OAuth fixture has no token_unlimited entry: ${fixturePath}`
   );
}

tokens.default = { ...tokens.token_unlimited };
