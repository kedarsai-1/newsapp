module.exports = {
  apps: [
    {
      name: 'newsapp',
      script: 'server.js',
      cwd: __dirname,
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 15,
      min_uptime: '30s',
      max_memory_restart: '900M',
      node_args: '--max-old-space-size=768',
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
