const http = require('http');

const config = {
  host: 'mcp.dev.beepmedia.com',
  port: 80,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

// Keep persistent session
let sessionId = null;

function sendRequest(method, params = {}) {
  return new Promise((resolve, reject) => {
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
        'Content-Length': Buffer.byteLength(request)
      }
    };

    if (sessionId) {
      options.headers['Mcp-Session-Id'] = sessionId;
    }

    const req = http.request(options, (res) => {
      if (!sessionId && res.headers['mcp-session-id']) {
        sessionId = res.headers['mcp-session-id'];
      }

      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(data);
          resolve(response);
        } catch (e) {
          // For 202 responses, just resolve
          resolve({ status: res.statusCode });
        }
      });
    });

    req.on('error', reject);
    req.write(request);
    req.end();
  });
}

async function main() {
  try {
    // Initialize
    console.log('1. Initializing...');
    const initResponse = await sendRequest('initialize', {
      protocolVersion: '1.0.0',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    });
    console.log('Init response:', initResponse);

    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 500));

    // List tools
    console.log('\n2. Listing tools...');
    const toolsResponse = await sendRequest('tools/list');
    console.log('Tools response:', toolsResponse);

    // Try to call search
    console.log('\n3. Searching for users...');
    const searchResponse = await sendRequest('tools/call', {
      name: 'search',
      arguments: {
        query: 'user',
        filter: {
          property: 'object',
          value: 'user'
        }
      }
    });
    console.log('Search response:', searchResponse);

  } catch (error) {
    console.error('Error:', error);
  }
}

main();