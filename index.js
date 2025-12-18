// Root fallback entry point - redirects to backend/server.js
// This handles cases where Railway ignores railway.toml and defaults to index.js
require('./backend/server.js');