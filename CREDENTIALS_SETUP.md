# Credentials Setup Guide

This application uses two methods for managing secrets:

## 1. Environment Variables (Recommended for Development)

### Setup for New Developers

1. **Copy the example file:**
   ```bash
   cp config/.env.example .env
   ```

2. **Generate secrets:**
   ```bash
   # Generate SECRET_KEY_BASE
   echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
   
   # Generate DEVISE_JWT_SECRET_KEY
   echo "DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)" >> .env
   ```

3. **Verify your .env file:**
   ```bash
   cat .env
   ```
   
   Should contain:
   ```
   DATABASE_USERNAME=postgres
   DATABASE_PASSWORD=postgres
   SECRET_KEY_BASE=<generated-hex-string>
   DEVISE_JWT_SECRET_KEY=<generated-hex-string>
   RAILS_ENV=development
   ```

### Sharing Credentials with Team (Development)

**DO NOT commit `.env` to git** (it's already in `.gitignore`)

**Option A: Secure sharing tools**
- Use 1Password, LastPass, or similar password managers
- Share via encrypted communication (Signal, encrypted email)
- Use secret management tools (HashiCorp Vault, AWS Secrets Manager)

**Option B: Team setup script**
Create a script for the team to generate their own:
```bash
#!/bin/bash
# scripts/setup_env.sh
if [ ! -f .env ]; then
  cp config/.env.example .env
  echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
  echo "DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)" >> .env
  echo "✅ .env file created with secure secrets"
else
  echo "⚠️  .env file already exists"
fi
```

## 2. Rails Encrypted Credentials (Recommended for Production)

Rails uses encrypted credentials stored in `config/credentials.yml.enc`, which can be safely committed to git.

### How It Works

- **Encrypted file:** `config/credentials.yml.enc` (safe to commit)
- **Master key:** `config/master.key` (NEVER commit - in `.gitignore`)
- The master key decrypts the credentials file

### Viewing Credentials

```bash
# Using Docker
docker-compose exec web rails credentials:edit

# Or locally
EDITOR="code --wait" rails credentials:edit
```

This opens the decrypted credentials. Example content:
```yaml
secret_key_base: your_secret_key_here
devise_jwt_secret_key: your_jwt_secret_here

production:
  database:
    username: prod_user
    password: prod_password
```

### Sharing `master.key` with Team

The `config/master.key` file is required to decrypt credentials.

**Secure sharing methods:**

1. **Password Manager** (Best)
   - Store in 1Password, LastPass, etc.
   - Share with team members securely

2. **Encrypted Communication**
   - Send via Signal, encrypted email, or Keybase
   - Delete after sharing

3. **CI/CD Setup**
   - Store as `RAILS_MASTER_KEY` environment variable in CI/CD
   - GitHub Actions: Repository Secrets
   - GitLab CI: CI/CD Variables
   - Heroku: Config Vars

**Example for new developer:**
```bash
# Team lead sends master.key securely
# Developer saves it to config/master.key
echo "paste-master-key-here" > config/master.key
chmod 600 config/master.key
```

### Priority Order

The application checks for secrets in this order:

1. Environment variables (`.env` file)
2. Rails credentials (`credentials.yml.enc`)
3. Fallback to `secret_key_base`

See [config/initializers/devise.rb](config/initializers/devise.rb#L316):
```ruby
jwt.secret = Rails.application.credentials.devise_jwt_secret_key || 
             ENV["DEVISE_JWT_SECRET_KEY"] || 
             Rails.application.credentials.secret_key_base
```

## Production Setup

### Using Environment Variables

```bash
# On production server or CI/CD
export SECRET_KEY_BASE=$(openssl rand -hex 64)
export DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)
export DATABASE_PASSWORD=secure_production_password
```

### Using Rails Credentials

```bash
# Set RAILS_MASTER_KEY environment variable
export RAILS_MASTER_KEY=your_master_key_content

# Rails will automatically decrypt credentials.yml.enc
```

## Security Checklist

- [ ] `.env` is in `.gitignore` ✓
- [ ] `config/master.key` is in `.gitignore` ✓
- [ ] Never commit secrets to git
- [ ] Use different secrets for each environment
- [ ] Rotate secrets periodically
- [ ] Use strong, randomly generated secrets (min 64 chars)
- [ ] Share secrets through secure channels only
- [ ] Document how team members should obtain secrets

## Troubleshooting

### "Missing secret_key_base" error

**Solution:** Ensure you have either:
- `.env` file with `SECRET_KEY_BASE` set, OR
- `config/master.key` file exists

### "ActiveSupport::MessageEncryptor::InvalidMessage" error

**Cause:** Wrong or missing `master.key`

**Solution:** 
1. Get the correct `master.key` from team lead
2. Save to `config/master.key`
3. Restart the application

### Generating new credentials file

```bash
# Delete existing credentials (WARNING: loses all secrets)
rm config/credentials.yml.enc config/master.key

# Generate new credentials
docker-compose exec web rails credentials:edit
```

## Additional Resources

- [Rails Credentials Documentation](https://guides.rubyonrails.org/security.html#custom-credentials)
- [Environment Variables Best Practices](https://12factor.net/config)
