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
        // Fetch real pod data directly using kubectl commands
        const kubectlCommands = [
            'kubectl --context workload-cluster -n spire-server get pods -o json',
            'kubectl --context workload-cluster -n spire-server get pvc -o json',
            'kubectl --context workload-cluster -n spire-server get svc -o json',
            'kubectl --context workload-cluster -n spire-system get pods -o json',
            'kubectl --context workload-cluster -n production get pods -o json'
        ];
        
        Promise.all(kubectlCommands.map(cmd => 
            new Promise((resolve, reject) => {
                exec(cmd, { timeout: 10000 }, (error, stdout, stderr) => {
                    if (error) {
                        console.warn(`Command failed: ${cmd}`, error.message);
                        resolve({ items: [] }); // Return empty result on error
                    } else {
                        try {
                            resolve(JSON.parse(stdout));
                        } catch (parseError) {
                            console.warn(`Parse error for: ${cmd}`, parseError.message);
                            resolve({ items: [] });
                        }
                    }
                });
            })
        )).then(([serverPods, serverPVC, serverSVC, agentPods, workloadPods]) => {
            const podData = {
                server: serverPods.items.filter(pod => pod.metadata.name.startsWith('spire-server')),
                database: serverPods.items.filter(pod => pod.metadata.name.startsWith('spire-db')),
                storage: serverPVC.items.filter(pvc => pvc.metadata.name.startsWith('postgres')),
                dbService: serverSVC.items.filter(svc => svc.metadata.name.startsWith('spire-db')),
                agents: agentPods.items.filter(pod => pod.metadata.name.startsWith('spire-agent')),
                workloads: workloadPods.items
            };
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(podData));
        }).catch(err => {
            console.error('Error fetching pod data:', err);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
                error: 'Failed to fetch pod data', 
                details: err.message 
            }));
        });
    } else if (req.url.startsWith('/api/describe/') && req.method === 'GET') {
        // Handle kubectl describe requests
        const urlParts = req.url.split('/');
        if (urlParts.length >= 6) {
            const resourceType = urlParts[3]; // pod, service, etc.
            const namespace = urlParts[4];
            const context = urlParts[5];
            const resourceName = urlParts[6];
            
            // Security check - only allow specific contexts and namespaces
            const allowedContexts = ['spire-server-cluster', 'workload-cluster'];
            const allowedNamespaces = ['spire-server', 'spire-system', 'production'];
            const allowedResourceTypes = ['pod', 'service', 'pvc', 'deployment', 'daemonset', 'statefulset'];
            
            if (!allowedContexts.includes(context) || 
                !allowedNamespaces.includes(namespace) || 
                !allowedResourceTypes.includes(resourceType)) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Invalid resource parameters' }));
                return;
            }
            
            const command = `kubectl --context ${context} -n ${namespace} describe ${resourceType} ${resourceName}`;
            
            exec(command, { timeout: 15000 }, (error, stdout, stderr) => {
                if (error) {
                    console.warn(`Describe command failed: ${command}`, error.message);
                    res.writeHead(500, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ 
                        error: 'Failed to describe resource', 
                        details: error.message,
                        command: command
                    }));
                } else {
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ 
                        output: stdout,
                        command: command,
                        resource: {
                            type: resourceType,
                            name: resourceName,
                            namespace: namespace,
                            context: context
                        }
                    }));
                }
            });
        } else {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Invalid describe URL format. Expected: /api/describe/{type}/{namespace}/{context}/{name}' }));
        }
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