const express = require('express');
const { spawn } = require('child_process');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

// Store active sessions
const sessions = new Map();

// Basic auth middleware
const basicAuth = (req, res, next) => {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Basic ')) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  
  const [username, password] = Buffer.from(auth.split(' ')[1], 'base64').toString().split(':');
  if (username === 'beepmedia' && password === process.env.MCP_API_KEY) {
    next();
  } else {
    res.status(401).json({ error: 'Invalid credentials' });
  }
};

// MCP server configurations - using local executables
const MCP_SERVERS = {
  'pdf-reader': {
    command: 'python',
    args: ['/app/mcp-servers/pdf-reader/mcp_pdf_reader.py'],
    env: {}
  },
  'notion': {
    command: 'node',
    args: ['/app/mcp-servers/notion/dist/index.js'],
    env: {
      NOTION_API_KEY: process.env.NOTION_API_KEY
    }
  },
  'aws': {
    command: 'python',
    args: ['-m', 'awslabs.core-mcp-server.server'],
    env: {
      AWS_REGION: process.env.AWS_REGION || 'us-east-1',
      AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
      AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY
    }
  }
};

// Create MCP session with direct process spawning
async function createMcpSession(serverType) {
  const config = MCP_SERVERS[serverType];
  if (!config) {
    throw new Error(`Unknown server type: ${serverType}`);
  }

  const sessionId = uuidv4();
  
  // Spawn the MCP server process directly
  const mcpProcess = spawn(config.command, config.args, {
    env: { ...process.env, ...config.env },
    stdio: ['pipe', 'pipe', 'pipe']
  });
  
  const session = {
    id: sessionId,
    serverType,
    process: mcpProcess,
    responses: [],
    buffer: '',
    eventEmitter: null,
    initialized: false
  };

  // Handle stdout data
  mcpProcess.stdout.on('data', (data) => {
    session.buffer += data.toString();
    const lines = session.buffer.split('\n');
    session.buffer = lines.pop() || '';
    
    lines.forEach(line => {
      if (line.trim()) {
        try {
          const response = JSON.parse(line);
          session.responses.push(response);
          
          // Check if this is the initialization response
          if (response.result && response.result.protocolVersion) {
            session.initialized = true;
          }
          
          if (session.eventEmitter) {
            session.eventEmitter.write(`data: ${JSON.stringify(response)}\n\n`);
          }
        } catch (e) {
          console.error('Failed to parse MCP response:', line);
        }
      }
    });
  });

  // Handle stderr
  mcpProcess.stderr.on('data', (data) => {
    console.error(`MCP stderr (${serverType}):`, data.toString());
  });

  // Handle process exit
  mcpProcess.on('exit', (code, signal) => {
    console.log(`MCP process ${serverType} exited with code ${code}, signal ${signal}`);
    sessions.delete(sessionId);
  });

  sessions.set(sessionId, session);
  return session;
}

// POST endpoint for MCP requests
app.post('/mcp/:serverType', basicAuth, async (req, res) => {
  try {
    let sessionId = req.headers['mcp-session-id'];
    let session;

    if (sessionId && sessions.has(sessionId)) {
      session = sessions.get(sessionId);
    } else {
      session = await createMcpSession(req.params.serverType);
      sessionId = session.id;
    }

    // Send request to MCP server
    const request = req.body;
    session.process.stdin.write(JSON.stringify(request) + '\n');

    // Set headers
    res.setHeader('Mcp-Session-Id', sessionId);

    // Check Accept header for SSE
    if (req.headers.accept && req.headers.accept.includes('text/event-stream')) {
      // Return SSE stream
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      res.setHeader('X-Accel-Buffering', 'no'); // Disable nginx buffering
      
      session.eventEmitter = res;
      
      // Send any buffered responses
      session.responses.forEach(response => {
        res.write(`data: ${JSON.stringify(response)}\n\n`);
      });
      session.responses = [];

      // Keep connection alive
      const heartbeat = setInterval(() => {
        res.write(':heartbeat\n\n');
      }, 30000);

      req.on('close', () => {
        clearInterval(heartbeat);
        session.eventEmitter = null;
        // Clean up the MCP process when client disconnects
        if (session.process && !session.process.killed) {
          session.process.kill();
        }
        sessions.delete(sessionId);
      });
    } else {
      // Wait a bit for initialization if new session
      if (!session.initialized) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      // Return the first response or 202
      if (session.responses.length > 0) {
        const response = session.responses.shift();
        res.json(response);
      } else {
        res.status(202).json({ sessionId });
      }
    }
  } catch (error) {
    console.error('Error handling MCP request:', error);
    res.status(500).json({ error: error.message });
  }
});

// GET endpoint for polling responses
app.get('/mcp/:serverType/poll', basicAuth, (req, res) => {
  const sessionId = req.headers['mcp-session-id'];
  if (!sessionId || !sessions.has(sessionId)) {
    res.status(400).json({ error: 'Invalid session ID' });
    return;
  }

  const session = sessions.get(sessionId);
  
  if (session.responses.length > 0) {
    const responses = session.responses.splice(0, session.responses.length);
    res.json({ responses });
  } else {
    res.json({ responses: [] });
  }
});

// Health check with more details
app.get('/health', (req, res) => {
  const serverStatuses = {};
  sessions.forEach((session, id) => {
    const key = `${session.serverType}-${id.substring(0, 8)}`;
    serverStatuses[key] = {
      alive: !session.process.killed,
      initialized: session.initialized,
      responseCount: session.responses.length
    };
  });
  
  res.json({ 
    status: 'OK',
    uptime: process.uptime(),
    activeSessions: sessions.size,
    sessions: serverStatuses,
    availableServers: Object.keys(MCP_SERVERS)
  });
});

// Cleanup dead sessions periodically
setInterval(() => {
  sessions.forEach((session, id) => {
    if (session.process.killed) {
      sessions.delete(id);
    }
  });
}, 60000);

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  sessions.forEach((session) => {
    if (!session.process.killed) {
      session.process.kill();
    }
  });
  process.exit(0);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`MCP HTTP Bridge running on port ${PORT}`);
  console.log('Available MCP servers:', Object.keys(MCP_SERVERS).join(', '));
  console.log('Authentication enabled:', true);
});