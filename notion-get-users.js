const http = require('http');

const config = {
  host: 'mcp.dev.beepmedia.com',
  port: 80,
  auth: 'beepmedia:9acdab5d85f7ca1973ff8932c73fb9a8e5db434d90465e6c0a61e4b77725837b'
};

const authHeader = 'Basic ' + Buffer.from(config.auth).toString('base64');

function sendMCPRequest(method, params = {}, waitTime = 5000) {
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

    const req = http.request(options, (res) => {
      console.log(`[${method}] Status: ${res.statusCode}`);
      
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
              console.log('Response received:', JSON.stringify(json, null, 2));
            } catch (e) {
              // Ignore parse errors
            }
          }
        });
      });
      
      // Wait for responses then close
      setTimeout(() => {
        req.destroy();
        resolve(responses);
      }, waitTime);
    });

    req.on('error', reject);
    req.write(request);
    req.end();
  });
}

async function main() {
  try {
    console.log('=== Getting Notion Users ===\n');
    
    // Initialize
    console.log('1. Initializing connection...');
    await sendMCPRequest('initialize', {
      protocolVersion: '1.0.0',
      capabilities: {},
      clientInfo: { name: 'notion-user-test', version: '1.0' }
    }, 2000);
    
    // Get users
    console.log('\n2. Getting users list...');
    const usersResponses = await sendMCPRequest('tools/call', {
      name: 'API-get-users',
      arguments: {
        page_size: 100
      }
    });
    
    // Find the result
    const userResult = usersResponses.find(r => r.result && r.result.content);
    if (userResult) {
      console.log('\n=== USERS FOUND ===');
      const content = JSON.parse(userResult.result.content[0].text);
      console.log(JSON.stringify(content, null, 2));
      
      if (content.results) {
        console.log('\n=== USER SUMMARY ===');
        content.results.forEach(user => {
          console.log(`- ${user.name} (${user.type}) - ${user.type === 'person' ? user.person.email : 'Bot'}`);
        });
      }
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

main();