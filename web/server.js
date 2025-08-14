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
            'kubectl --context workload-cluster -n spire-workload get pods -o json'
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
                storage: serverPVC.items.filter(pvc => pvc.metadata.name.startsWith('mysql')),
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
            const allowedNamespaces = ['spire-server', 'spire-system', 'spire-workload'];
            const allowedResourceTypes = ['pod', 'service', 'pvc', 'deployment', 'daemonset', 'statefulset'];
            
            if (!allowedContexts.includes(context) || 
                !allowedNamespaces.includes(namespace) || 
                !allowedResourceTypes.includes(resourceType)) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ error: 'Invalid resource parameters' }));
                return;
            }
            
            const command = `kubectl --context ${context} -n ${namespace} describe ${resourceType} ${resourceName}`;
            
            // Enhanced pod details for workload namespace - include SPIFFE information
            if (resourceType === 'pod' && namespace === 'spire-workload') {
                // Get enhanced pod details with SPIFFE information
                const enhancedCommands = [
                    `kubectl --context ${context} -n ${namespace} describe ${resourceType} ${resourceName}`,
                    `kubectl --context ${context} -n spire-server exec spire-server-0 -- /opt/spire/bin/spire-server entry show -socketPath /run/spire/sockets/server.sock 2>/dev/null || echo "SPIFFE entries not available"`,
                    `kubectl --context ${context} -n ${namespace} get pod ${resourceName} -o jsonpath='{.metadata.labels}' 2>/dev/null || echo "{}"`,
                    `kubectl --context ${context} -n ${namespace} get pod ${resourceName} -o jsonpath='{.spec.serviceAccountName}' 2>/dev/null || echo "default"`
                ];

                // Execute all commands in parallel
                Promise.all(enhancedCommands.map(cmd => 
                    new Promise((resolve) => {
                        exec(cmd, { timeout: 15000 }, (error, stdout, stderr) => {
                            resolve({ cmd, stdout: stdout || '', stderr: stderr || '', error: error ? error.message : null });
                        });
                    })
                )).then(results => {
                    const [describeResult, spiffeResult, labelsResult, saResult] = results;
                    
                    if (describeResult.error) {
                        res.writeHead(500, { 'Content-Type': 'application/json' });
                        res.end(JSON.stringify({ 
                            error: 'Failed to describe resource', 
                            details: describeResult.error,
                            command: command
                        }));
                        return;
                    }

                    // Parse SPIFFE entries to find matching ones
                    let spiffeInfo = null;
                    if (!spiffeResult.error && spiffeResult.stdout) {
                        const spiffeOutput = spiffeResult.stdout;
                        const entries = spiffeOutput.split('Entry ID').filter(entry => entry.trim().length > 0);
                        
                        // Try to find entry that matches this workload
                        const serviceAccountName = saResult.stdout.trim();
                        const matchingEntry = entries.find(entry => {
                            return entry.includes(`k8s:ns:${namespace}`) && 
                                   entry.includes(`k8s:sa:${serviceAccountName}`);
                        });

                        if (matchingEntry) {
                            // Extract SPIFFE ID
                            const spiffeIdMatch = matchingEntry.match(/SPIFFE ID\s*:\s*([^\n\r]+)/);
                            const parentIdMatch = matchingEntry.match(/Parent ID\s*:\s*([^\n\r]+)/);
                            const ttlMatch = matchingEntry.match(/TTL\s*:\s*([^\n\r]+)/);
                            const selectorsMatch = matchingEntry.match(/Selector\s*:\s*([^\n\r]+)/g);

                            spiffeInfo = {
                                spiffeId: spiffeIdMatch ? spiffeIdMatch[1].trim() : null,
                                parentId: parentIdMatch ? parentIdMatch[1].trim() : null,
                                ttl: ttlMatch ? ttlMatch[1].trim() : null,
                                selectors: selectorsMatch ? selectorsMatch.map(s => s.replace('Selector     :', '').trim()) : [],
                                hasRegistration: true
                            };
                        }
                    }

                    // Parse pod labels for additional context
                    let podLabels = {};
                    try {
                        podLabels = JSON.parse(labelsResult.stdout) || {};
                    } catch (e) {
                        podLabels = {};
                    }

                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ 
                        output: describeResult.stdout,
                        command: command,
                        resource: {
                            type: resourceType,
                            name: resourceName,
                            namespace: namespace,
                            context: context
                        },
                        spiffeInfo: spiffeInfo,
                        podLabels: podLabels,
                        serviceAccount: saResult.stdout.trim(),
                        enhanced: true
                    }));
                });
            } else {
                // Standard describe for non-workload pods
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
            }
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