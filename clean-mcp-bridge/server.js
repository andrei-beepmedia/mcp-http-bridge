const express = require('express');
const { spawn } = require('child_process');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

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

// MCP server configurations
const MCP_SERVERS = {
  'pdf-reader': {
    mode: 'run',
    image: 'mcp-pdf-reader:latest',
    command: 'python',
    args: ['mcp_pdf_reader.py']
  },
  'notion': {
    mode: 'run',
    image: 'mcp-notion:latest',
    command: 'notion-mcp-server',
    env: {
      NOTION_API_KEY: process.env.NOTION_API_KEY
    }
  },
  'aws': {
    mode: 'run',
    image: 'mcp-aws:latest',
    command: 'awslabs.core-mcp-server.server',
    env: {
      AWS_REGION: process.env.AWS_REGION || 'us-east-1',
      AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
      AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY
    }
  }
};

// Create MCP session
async function createMcpSession(serverType) {
  const config = MCP_SERVERS[serverType];
  if (!config) {
    throw new Error(`Unknown server type: ${serverType}`);
  }

  const sessionId = uuidv4();
  let args;
  
  if (config.mode === 'run') {
    // Run a new container
    args = ['run', '--rm', '-i'];
    
    // Add environment variables
    if (config.env) {
      Object.entries(config.env).forEach(([key, value]) => {
        args.push('-e', `${key}=${value}`);
      });
    }
    
    args.push(config.image, config.command);
    if (config.args && Array.isArray(config.args)) {
      args.push(...config.args);
    }
  } else {
    // Exec into existing container
    args = ['exec', '-i', config.container, config.command];
    if (config.args && Array.isArray(config.args)) {
      args.push(...config.args);
    }
  }
  
  const mcpProcess = spawn('docker', args);
  
  const session = {
    id: sessionId,
    serverType,
    process: mcpProcess,
    responses: [],
    eventEmitter: null
  };

  mcpProcess.stdout.on('data', (data) => {
    const lines = data.toString().split('\n').filter(line => line.trim());
    lines.forEach(line => {
      try {
        const response = JSON.parse(line);
        session.responses.push(response);
        if (session.eventEmitter) {
          session.eventEmitter.write(`data: ${JSON.stringify(response)}\n\n`);
        }
      } catch (e) {
        console.error('Failed to parse MCP response:', line);
      }
    });
  });

  mcpProcess.stderr.on('data', (data) => {
    console.error(`MCP stderr (${serverType}):`, data.toString());
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

    // Handle request/notification
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
      });
    } else {
      // Return 202 Accepted
      res.status(202).send();
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET endpoint for SSE stream
app.get('/mcp/:serverType', basicAuth, async (req, res) => {
  try {
    const sessionId = req.headers['mcp-session-id'];
    if (!sessionId || !sessions.has(sessionId)) {
      res.status(400).json({ error: 'Invalid session ID' });
      return;
    }

    const session = sessions.get(sessionId);
    
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    
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
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.send('OK');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`MCP HTTP Bridge running on port ${PORT}`);
});