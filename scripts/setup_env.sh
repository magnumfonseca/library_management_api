#!/bin/bash
# Script to set up environment variables for new developers

set -e

echo "🔧 Library Management System - Environment Setup"
echo ""

# Check if .env already exists
if [ -f .env ]; then
  echo "⚠️  .env file already exists!"
  read -p "Do you want to overwrite it? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled"
    exit 1
  fi
fi

# Check if config/.env.example exists
if [ ! -f config/.env.example ]; then
  echo "❌ Error: config/.env.example not found!"
  exit 1
fi

echo "📋 Copying config/.env.example to .env..."
cp config/.env.example .env

echo "🔐 Generating secure secrets..."

# Generate SECRET_KEY_BASE
SECRET_KEY_BASE=$(openssl rand -hex 64)
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> .env

# Generate DEVISE_JWT_SECRET_KEY
DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)
echo "DEVISE_JWT_SECRET_KEY=$DEVISE_JWT_SECRET_KEY" >> .env

echo ""
echo "✅ Environment setup complete!"
echo ""
echo "📄 Your .env file has been created with:"
echo "   - Database credentials"
echo "   - Generated SECRET_KEY_BASE"
echo "   - Generated DEVISE_JWT_SECRET_KEY"
echo ""
echo "⚠️  IMPORTANT: Never commit .env to version control!"
echo ""
echo "🚀 You can now run: docker-compose up --build"
