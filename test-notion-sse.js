const http = require('http');

const config = {
  host: 'mcp.dev.beepmedia.com',
  port: 80,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

async function sendInitialRequest(method, params = {}) {
  const request = JSON.stringify({
    jsonrpc: '2.0',
    method: method,
    params: params,
    id: Date.now()
  });

  const options = {
    hostname: config.host,
    port: config.port,
    path: '/mcp/notion',
    method: 'POST',
    headers: {
      'Authorization': authHeader,
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Content-Length': Buffer.byteLength(request)
    }
  };

  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      console.log(`Status: ${res.statusCode}`);
      console.log(`Session ID: ${res.headers['mcp-session-id']}`);
      
      if (res.statusCode === 200 && res.headers['content-type'] === 'text/event-stream') {
        const sessionId = res.headers['mcp-session-id'];
        
        let responses = [];
        res.on('data', chunk => {
          const data = chunk.toString();
          const lines = data.split('\n');
          
          lines.forEach(line => {
            if (line.startsWith('data: ')) {
              try {
                const json = JSON.parse(line.substring(6));
                responses.push(json);
                console.log('Response:', JSON.stringify(json, null, 2));
              } catch (e) {
                // Ignore
              }
            }
          });
        });
        
        // Collect responses for 2 seconds then resolve
        setTimeout(() => {
          req.destroy();
          resolve({ sessionId, responses });
        }, 2000);
      } else {
        res.on('data', () => {});
        res.on('end', () => {
          resolve({ sessionId: res.headers['mcp-session-id'] });
        });
      }
    });

    req.on('error', reject);
    req.write(request);
    req.end();
  });
}

async function main() {
  try {
    // 1. Initialize
    console.log('1. Initializing MCP connection...');
    const initResult = await sendInitialRequest('initialize', {
      protocolVersion: '1.0.0',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    });
    
    const sessionId = initResult.sessionId;
    console.log(`\nSession established: ${sessionId}`);

    // 2. List tools - wait for response
    console.log('\n2. Listing available tools...');
    await new Promise(resolve => setTimeout(resolve, 1000));
    const toolsResult = await sendInitialRequest('tools/list');
    
    // 3. Try to use search tool
    console.log('\n3. Calling search tool to find users...');
    const searchResult = await sendInitialRequest('tools/call', {
      name: 'search',
      arguments: {
        query: 'all users',
        filter: {
          property: 'object',
          value: 'user'
        }
      }
    });

    // 4. Direct users list
    console.log('\n4. Trying direct users list...');
    const usersResult = await sendInitialRequest('notion/users/list', {});

  } catch (error) {
    console.error('Error:', error);
  }
}

main();