#!/bin/bash
# Setup test environment with dummy credentials

# Create test credentials file
cat > /tmp/test-mcp-secrets.env << EOF
# AWS Test Credentials (dummy)
AWS_ACCESS_KEY_ID=AKIATEST123456789012
AWS_SECRET_ACCESS_KEY=testSecretKey123456789012345678901234567
AWS_REGION=us-east-1

# API Keys (test/dummy values)
NOTION_API_KEY=secret_test_notion_key_123456789
STRIPE_API_KEY=sk_test_123456789
OPENAI_API_KEY=sk-test-123456789
SLACK_TOKEN=xoxb-test-123456789
GITHUB_TOKEN=ghp_test123456789
CLOUDFLARE_API_TOKEN=test_cloudflare_token_123456789
PAYPAL_ACCESS_TOKEN=test_paypal_token_123456789
SHOPIFY_API_KEY=test_shopify_key_123456789
FIRECRAWL_API_KEY=test_firecrawl_key_123456789
ELEVENLABS_API_KEY=test_elevenlabs_key_123456789
ALCHEMY_API_KEY=test_alchemy_key_123456789
REDIS_URL=redis://localhost:6379

# Google Service Account (dummy JSON)
GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"test-project","private_key_id":"test123","private_key":"-----BEGIN PRIVATE KEY-----\nMIIEvQtest\n-----END PRIVATE KEY-----\n","client_email":"test@test-project.iam.gserviceaccount.com","client_id":"123456789","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_x509_cert_url":"https://www.googleapis.com/robot/v1/metadata/x509/test%40test-project.iam.gserviceaccount.com"}'

# MCP Test Mode
MCP_TEST_MODE=true
EOF

echo "Test environment setup complete. Use: source /tmp/test-mcp-secrets.env"