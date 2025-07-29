#!/usr/bin/env node

const http = require('http');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const PORT = 3000;

// Detect deployment type by checking for contexts
function detectDeploymentType() {
    return new Promise((resolve) => {
        exec('kubectl config get-contexts --no-headers', (error, stdout) => {
            if (error) {
                resolve('basic');
                return;
            }
            
            const contexts = stdout.split('\n').map(line => line.trim());
            const hasUpstream = contexts.some(line => line.includes('upstream-spire-cluster'));
            const hasDownstream = contexts.some(line => line.includes('downstream-spire-cluster'));
            
            if (hasUpstream && hasDownstream) {
                resolve('enterprise');
            } else {
                resolve('basic');
            }
        });
    });
}

// Get pod data for basic deployment
async function getBasicPodData() {
    const kubectlCommands = [
        'kubectl --context workload-cluster -n spire-server get pods -o json',
        'kubectl --context workload-cluster -n spire-server get pvc -o json',
        'kubectl --context workload-cluster -n spire-server get svc -o json',
        'kubectl --context workload-cluster -n spire-system get pods -o json',  
        'kubectl --context workload-cluster -n production get pods -o json'
    ];
    
    const results = await Promise.all(kubectlCommands.map(cmd => 
        new Promise((resolve) => {
            exec(cmd, { timeout: 10000 }, (error, stdout) => {
                if (error) {
                    console.warn(`Command failed: ${cmd}`, error.message);
                    resolve({ items: [] });
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
    ));
    
    const [serverPods, serverPVC, serverSVC, agentPods, workloadPods] = results;
    
    return {
        deploymentType: 'basic',
        clusters: {
            'workload-cluster': {
                namespaces: {
                    'spire-server': {
                        pods: serverPods.items || [],
                        services: serverSVC.items || [],
                        pvcs: serverPVC.items || []
                    },
                    'spire-system': {
                        pods: agentPods.items || []
                    },
                    'production': {
                        pods: workloadPods.items || []
                    }
                }
            }
        }
    };
}

// Get pod data for enterprise deployment
async function getEnterprisePodData() {
    const kubectlCommands = [
        // Upstream cluster
        'kubectl --context upstream-spire-cluster -n spire-upstream get pods -o json',
        'kubectl --context upstream-spire-cluster -n spire-upstream get svc -o json',
        'kubectl --context upstream-spire-cluster -n spire-upstream get pvc -o json',
        // Downstream cluster
        'kubectl --context downstream-spire-cluster -n spire-downstream get pods -o json',
        'kubectl --context downstream-spire-cluster -n spire-downstream get svc -o json', 
        'kubectl --context downstream-spire-cluster -n spire-downstream get pvc -o json',
        'kubectl --context downstream-spire-cluster -n downstream-workloads get pods -o json',
        'kubectl --context downstream-spire-cluster -n downstream-workloads get svc -o json'
    ];
    
    const results = await Promise.all(kubectlCommands.map(cmd => 
        new Promise((resolve) => {
            exec(cmd, { timeout: 10000 }, (error, stdout) => {
                if (error) {
                    console.warn(`Command failed: ${cmd}`, error.message);
                    resolve({ items: [] });
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
    ));
    
    const [
        upstreamPods, upstreamSvc, upstreamPvc,
        downstreamPods, downstreamSvc, downstreamPvc, 
        workloadPods, workloadSvc
    ] = results;
    
    return {
        deploymentType: 'enterprise',
        clusters: {
            'upstream-spire-cluster': {
                namespaces: {
                    'spire-upstream': {
                        pods: upstreamPods.items || [],
                        services: upstreamSvc.items || [],
                        pvcs: upstreamPvc.items || []
                    }
                }
            },
            'downstream-spire-cluster': {
                namespaces: {
                    'spire-downstream': {
                        pods: downstreamPods.items || [],
                        services: downstreamSvc.items || [],
                        pvcs: downstreamPvc.items || []
                    },
                    'downstream-workloads': {
                        pods: workloadPods.items || [],
                        services: workloadSvc.items || []
                    }
                }
            }
        }
    };
}

const server = http.createServer(async (req, res) => {
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
        try {
            const deploymentType = await detectDeploymentType();
            let podData;
            
            if (deploymentType === 'enterprise') {
                podData = await getEnterprisePodData();
            } else {
                podData = await getBasicPodData();
            }
            
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(podData));
        } catch (error) {
            console.error('Error fetching pod data:', error);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
                error: 'Failed to fetch pod data',
                deploymentType: 'unknown',
                clusters: {}
            }));
        }
    } else if (req.url === '/web-dashboard.html' && req.method === 'GET') {
        // Serve the dashboard HTML
        const htmlPath = path.join(__dirname, 'enterprise-dashboard.html');
        fs.readFile(htmlPath, 'utf8', (err, data) => {
            if (err) {
                res.writeHead(404);
                res.end('Dashboard not found');
                return;
            }
            res.writeHead(200, { 'Content-Type': 'text/html' });
            res.end(data);
        });
    } else if (req.url === '/docs' && req.method === 'GET') {
        // Redirect to documentation server
        res.writeHead(302, { 'Location': 'http://localhost:8000' });
        res.end();
    } else if (req.url === '/' && req.method === 'GET') {
        // Redirect to dashboard
        res.writeHead(302, { 'Location': '/web-dashboard.html' });
        res.end();
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

server.listen(PORT, () => {
    console.log(`🌐 SPIRE Enterprise Dashboard server running at http://localhost:${PORT}`);
    console.log(`📊 Dashboard URL: http://localhost:${PORT}/web-dashboard.html`);
    console.log(`🔄 Auto-detects basic or enterprise deployment`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down dashboard server...');
    server.close(() => {
        console.log('✅ Server shutdown complete');
        process.exit(0);
    });
});