const http = require('http');

// Test configuration
const config = {
  host: 'localhost',
  port: 3000,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

// Base64 encode auth
const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

// Test MCP endpoint
async function testMCP(serverType) {
  console.log(`\nTesting ${serverType} MCP...`);
  
  const initRequest = JSON.stringify({
    jsonrpc: '2.0',
    method: 'initialize',
    params: {
      protocolVersion: '1.0.0',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    },
    id: 1
  });

  const options = {
    hostname: config.host,
    port: config.port,
    path: `/mcp/${serverType}`,
    method: 'POST',
    headers: {
      'Authorization': authHeader,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Content-Length': Buffer.byteLength(initRequest)
    }
  };

  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      console.log(`Status: ${res.statusCode}`);
      console.log(`Headers:`, res.headers);
      
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log('Response:', data);
        resolve();
      });
    });

    req.on('error', (e) => {
      console.error(`Error: ${e.message}`);
      reject(e);
    });

    req.write(initRequest);
    req.end();
  });
}

// Run tests
async function runTests() {
  try {
    // Test health endpoint
    const healthReq = http.get(`http://${config.host}:${config.port}/health`, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log('Health check:', data);
      });
    });

    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Test MCP servers
    await testMCP('pdf-reader');
    await testMCP('notion');
    
  } catch (error) {
    console.error('Test failed:', error);
  }
}

console.log('Starting MCP HTTP Bridge tests...');
runTests();