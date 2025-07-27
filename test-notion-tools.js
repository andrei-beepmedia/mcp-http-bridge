const http = require('http');

const config = {
  host: 'mcp.dev.beepmedia.com',
  port: 80,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

async function sendMCPRequest(method, params = {}) {
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
      const sessionId = res.headers['mcp-session-id'];
      console.log(`Session ID: ${sessionId}`);
      
      let buffer = '';
      res.on('data', chunk => {
        const data = chunk.toString();
        buffer += data;
        
        // Parse SSE data
        const lines = data.split('\n');
        lines.forEach(line => {
          if (line.startsWith('data: ')) {
            try {
              const json = JSON.parse(line.substring(6));
              console.log('Response:', JSON.stringify(json, null, 2));
              resolve(json);
            } catch (e) {
              // Continue buffering
            }
          }
        });
      });
      
      res.on('end', () => {
        if (!buffer.includes('data: ')) {
          reject(new Error('No data received'));
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
    console.log('1. Initializing MCP connection...');
    await sendMCPRequest('initialize', {
      protocolVersion: '1.0.0',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    });

    // List tools
    console.log('\n2. Listing available tools...');
    const toolsResponse = await sendMCPRequest('tools/list');
    
    if (toolsResponse.result && toolsResponse.result.tools) {
      console.log('\nAvailable Notion tools:');
      toolsResponse.result.tools.forEach(tool => {
        console.log(`- ${tool.name}: ${tool.description}`);
      });
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

main();