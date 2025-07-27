const http = require('http');

// Test configuration
const config = {
  host: 'localhost',
  port: 3000,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

// Base64 encode auth
const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

// Test MCP endpoint with SSE
async function testMCPWithSSE(serverType) {
  console.log(`\nTesting ${serverType} MCP with SSE...`);
  
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

  return new Promise((resolve) => {
    const options = {
      hostname: config.host,
      port: config.port,
      path: `/mcp/${serverType}`,
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Content-Length': Buffer.byteLength(initRequest)
      }
    };

    const req = http.request(options, (res) => {
      console.log(`Status: ${res.statusCode}`);
      console.log(`Session ID:`, res.headers['mcp-session-id']);
      
      if (res.statusCode === 200 && res.headers['content-type'] === 'text/event-stream') {
        console.log('SSE connection established');
        
        res.on('data', chunk => {
          const data = chunk.toString();
          const lines = data.split('\n');
          
          lines.forEach(line => {
            if (line.startsWith('data: ')) {
              try {
                const json = JSON.parse(line.substring(6));
                console.log('Received:', JSON.stringify(json, null, 2));
              } catch (e) {
                // Ignore parsing errors
              }
            } else if (line.startsWith(':heartbeat')) {
              console.log('Heartbeat received');
            }
          });
        });
        
        // Close after 5 seconds
        setTimeout(() => {
          console.log('Closing connection...');
          req.destroy();
          resolve();
        }, 5000);
      } else {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          console.log('Response:', data);
          resolve();
        });
      }
    });

    req.on('error', (e) => {
      console.error(`Error: ${e.message}`);
      resolve();
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
    
    // Test MCP servers with SSE
    await testMCPWithSSE('pdf-reader');
    await testMCPWithSSE('notion');
    
  } catch (error) {
    console.error('Test failed:', error);
  }
}

console.log('Starting MCP HTTP Bridge SSE tests...');
runTests();