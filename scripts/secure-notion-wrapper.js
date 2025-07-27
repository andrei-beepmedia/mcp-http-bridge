#!/usr/bin/env node
import { getMCPSecret } from './aws-secrets-manager.js';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

/**
 * Secure wrapper for Notion MCP server that fetches API key from AWS Secrets Manager
 * This ensures API keys are never exposed in configuration files or environment
 */

async function startSecureNotionServer() {
  try {
    // Fetch Notion API key from AWS Secrets Manager
    const notionApiKey = await getMCPSecret('NOTION_API_KEY', true); // Use beepmedia account
    
    if (!notionApiKey) {
      throw new Error('Failed to retrieve Notion API key from AWS Secrets Manager');
    }

    // Get the directory of this script
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = dirname(__filename);
    
    // Path to the actual Notion MCP server
    const notionServerPath = join(__dirname, '../repos/mcp-notion/bin/cli.mjs');
    
    // Start the Notion MCP server with the API key from Secrets Manager
    const notionProcess = spawn('node', [notionServerPath], {
      env: {
        ...process.env,
        NOTION_API_KEY: notionApiKey
      },
      stdio: 'inherit'
    });

    notionProcess.on('error', (error) => {
      console.error('Failed to start Notion MCP server:', error);
      process.exit(1);
    });

    notionProcess.on('exit', (code) => {
      console.log(`Notion MCP server exited with code ${code}`);
      process.exit(code || 0);
    });

    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log('Received SIGINT, shutting down gracefully...');
      notionProcess.kill('SIGINT');
    });

    process.on('SIGTERM', () => {
      console.log('Received SIGTERM, shutting down gracefully...');
      notionProcess.kill('SIGTERM');
    });

  } catch (error) {
    console.error('Error starting secure Notion MCP server:', error);
    process.exit(1);
  }
}

// Start the server
startSecureNotionServer();