// Railway fallback entry point - redirects to backend/server.js
// Railway sometimes ignores railway.toml and defaults to index.js in root
require('./backend/server.js');