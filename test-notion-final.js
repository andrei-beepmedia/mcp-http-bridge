const http = require('http');

const config = {
  host: 'mcp.dev.beepmedia.com',
  port: 80,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');
let globalSessionId = null;

function makeRequest(method, params = {}, sessionId = null) {
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
        'Accept': 'text/event-stream',
        'Content-Length': Buffer.byteLength(request)
      }
    };

    if (sessionId || globalSessionId) {
      options.headers['Mcp-Session-Id'] = sessionId || globalSessionId;
    }

    const req = http.request(options, (res) => {
      if (!globalSessionId && res.headers['mcp-session-id']) {
        globalSessionId = res.headers['mcp-session-id'];
      }
      
      console.log(`\n[${method}] Status: ${res.statusCode}, Session: ${res.headers['mcp-session-id']}`);
      
      let fullData = '';
      const responses = [];
      
      res.on('data', chunk => {
        fullData += chunk.toString();
        const lines = fullData.split('\n');
        
        lines.forEach(line => {
          if (line.startsWith('data: ')) {
            try {
              const json = JSON.parse(line.substring(6));
              responses.push(json);
            } catch (e) {
              // Ignore
            }
          }
        });
      });
      
      // Wait for data then close
      setTimeout(() => {
        req.destroy();
        resolve(responses);
      }, 3000);
    });

    req.on('error', reject);
    req.write(request);
    req.end();
  });
}

async function main() {
  try {
    // 1. Initialize
    console.log('=== 1. Initializing MCP connection ===');
    const initResponses = await makeRequest('initialize', {
      protocolVersion: '1.0.0',
      capabilities: {},
      clientInfo: { name: 'test', version: '1.0' }
    });
    console.log('Init responses:', JSON.stringify(initResponses, null, 2));

    // 2. List tools
    console.log('\n=== 2. Listing available tools ===');
    const toolsResponses = await makeRequest('tools/list');
    console.log('Tools responses:', JSON.stringify(toolsResponses, null, 2));
    
    if (toolsResponses.length > 0 && toolsResponses[0].result && toolsResponses[0].result.tools) {
      console.log('\nAvailable tools:');
      toolsResponses[0].result.tools.forEach(tool => {
        console.log(`- ${tool.name}: ${tool.description}`);
      });
      
      // 3. Try to search
      const searchTool = toolsResponses[0].result.tools.find(t => t.name === 'search');
      if (searchTool) {
        console.log('\n=== 3. Using search tool ===');
        const searchResponses = await makeRequest('tools/call', {
          name: 'search',
          arguments: {
            query: 'users'
          }
        });
        console.log('Search responses:', JSON.stringify(searchResponses, null, 2));
      }
    }

  } catch (error) {
    console.error('Error:', error);
  }
}

main();