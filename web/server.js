#!/usr/bin/env node

const http = require('http');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const PORT = 3000;

const server = http.createServer((req, res) => {
    // Enable CORS for local development
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }

    if (req.url === '/api/pod-data' && req.method === 'GET') {
        // Execute the get-pod-data.sh script
        const scriptPath = path.join(__dirname, '..', 'scripts', 'get-pod-data.sh');
        
        exec(`bash "${scriptPath}"`, { timeout: 30000 }, (error, stdout, stderr) => {
            if (error) {
                console.error('Script execution error:', error);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ 
                    error: 'Failed to fetch pod data', 
                    details: error.message,
                    stderr: stderr 
                }));
                return;
            }

            try {
                // Parse the JSON output from the script
                const podData = JSON.parse(stdout);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify(podData));
            } catch (parseError) {
                console.error('JSON parse error:', parseError);
                console.error('Script output:', stdout);
                res.writeHead(500, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ 
                    error: 'Failed to parse pod data', 
                    details: parseError.message,
                    output: stdout 
                }));
            }
        });
    } else if (req.url === '/' || req.url === '/web-dashboard.html') {
        // Serve the web dashboard
        const dashboardPath = path.join(__dirname, 'web-dashboard.html');
        fs.readFile(dashboardPath, 'utf8', (err, data) => {
            if (err) {
                res.writeHead(404, { 'Content-Type': 'text/plain' });
                res.end('Dashboard not found');
                return;
            }
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(data);
        });
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not found');
    }
});

server.listen(PORT, () => {
    console.log(`SPIRE Dashboard server running at http://localhost:${PORT}`);
    console.log(`API endpoint: http://localhost:${PORT}/api/pod-data`);
    console.log(`Dashboard: http://localhost:${PORT}/web-dashboard.html`);
});