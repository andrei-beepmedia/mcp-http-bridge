import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

/**
 * Secure AWS Secrets Manager wrapper for MCP servers
 * Caches secrets in memory with TTL to reduce API calls
 */
class SecureSecretsManager {
  constructor(region = "us-east-1") {
    this.client = new SecretsManagerClient({ region });
    this.cache = new Map();
    this.cacheTTL = 3600000; // 1 hour in milliseconds
  }

  /**
   * Get secret from AWS Secrets Manager with caching
   * @param {string} secretName - Name of the secret in AWS
   * @param {string} key - Optional specific key within the secret
   * @returns {Promise<string|object>} Secret value
   */
  async getSecret(secretName, key = null) {
    const cacheKey = `${secretName}:${key || 'full'}`;
    const cached = this.cache.get(cacheKey);
    
    if (cached && cached.expiry > Date.now()) {
      return cached.value;
    }

    try {
      const command = new GetSecretValueCommand({ SecretId: secretName });
      const response = await this.client.send(command);
      
      let secretValue;
      if (response.SecretString) {
        try {
          secretValue = JSON.parse(response.SecretString);
        } catch {
          secretValue = response.SecretString;
        }
      } else {
        throw new Error("Binary secrets not supported");
      }

      // Extract specific key if requested
      const value = key && typeof secretValue === 'object' ? secretValue[key] : secretValue;
      
      // Cache the result
      this.cache.set(cacheKey, {
        value,
        expiry: Date.now() + this.cacheTTL
      });

      return value;
    } catch (error) {
      console.error(`Failed to retrieve secret ${secretName}:`, error.message);
      throw error;
    }
  }

  /**
   * Clear cache for security or refresh purposes
   */
  clearCache() {
    this.cache.clear();
  }
}

// MCP-specific secret mappings
const MCP_SECRET_MAPPINGS = {
  // Personal account secrets
  NOTION_API_KEY: "hasna/tool/notion/hasna/api",
  STRIPE_API_KEY: "hasna/tool/stripe/credentials",
  OPENAI_API_KEY: "hasna/tool/openai/api",
  SLACK_TOKEN: "hasna/tool/slack/credentials",
  GITHUB_TOKEN: "hasna/tool/github/credentials",
  
  // Beepmedia account secrets
  NOTION_API_KEY_BEEPMEDIA: "beepmedia/tool/notion/general/api",
  STRIPE_API_KEY_BEEPMEDIA: "beepmedia/tool/stripe/credentials",
  OPENAI_API_KEY_BEEPMEDIA: "beepmedia/tool/openai/api",
  SLACK_TOKEN_BEEPMEDIA: "beepmedia/tool/slack/production/bot",
  GITHUB_TOKEN_BEEPMEDIA: "beepmedia/tool/github/credentials",
  PERPLEXITY_API_KEY: "beepmedia/tool/mcp/perplexity/credentials",
  TWILIO_CREDENTIALS: "beepmedia/tool/twilio/credentials",
  SENDGRID_API_KEY: "beepmedia/tool/sendgrid/credentials",
  MAILGUN_CREDENTIALS: "beepmedia/tool/mailgun/credentials",
  DISCORD_CREDENTIALS: "beepmedia/tool/discord/credentials"
};

/**
 * Get MCP secret by name
 * @param {string} mcpSecretName - MCP secret identifier
 * @param {boolean} useBeepmedia - Use beepmedia account secrets
 * @returns {Promise<string|object>} Secret value
 */
export async function getMCPSecret(mcpSecretName, useBeepmedia = true) {
  const manager = new SecureSecretsManager();
  const secretKey = useBeepmedia && MCP_SECRET_MAPPINGS[`${mcpSecretName}_BEEPMEDIA`] 
    ? `${mcpSecretName}_BEEPMEDIA` 
    : mcpSecretName;
  
  const secretPath = MCP_SECRET_MAPPINGS[secretKey];
  if (!secretPath) {
    throw new Error(`Unknown MCP secret: ${mcpSecretName}`);
  }

  // Handle different secret formats
  if (secretPath.includes('credentials')) {
    const creds = await manager.getSecret(secretPath);
    if (typeof creds === 'object' && creds.password) {
      return creds.password; // Return API key from password field
    }
    return creds;
  }

  return manager.getSecret(secretPath);
}

// Export singleton instance
export const secretsManager = new SecureSecretsManager();
export { SecureSecretsManager, MCP_SECRET_MAPPINGS };