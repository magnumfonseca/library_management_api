# Library Management System

A Rails API application for managing library operations including books, borrowings, and user management with role-based access control.

## Prerequisites

- Docker
- Docker Compose
- Git

## Quick Start

### 1. Clone the repository

```bash
git clone <repository-url>
cd library_management
```

### 2. Set up environment variables

**Option A: Automated setup (Recommended)**

```bash
./scripts/setup_env.sh
```

This will create a `.env` file with secure, randomly generated secrets.

**Option B: Manual setup**

```bash
cp config/.env.example .env

# Generate secrets
echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" >> .env
echo "DEVISE_JWT_SECRET_KEY=$(openssl rand -hex 64)" >> .env
```

**Important:** 
- Never commit `.env` to git (already in `.gitignore`)
- For team sharing of credentials, see [CREDENTIALS_SETUP.md](CREDENTIALS_SETUP.md)

### 3. Build and start the application

```bash
docker-compose up --build
```

This will:
- Build the Rails application Docker image
- Start PostgreSQL database
- Create and migrate the database
- Start the Rails server on port 3000

### 4. Seed the database (in a new terminal)

```bash
docker-compose exec web rails db:seed
```

This creates:
- 2 Librarians
- 5 Members
- 20 Books
- Sample borrowings (active, overdue, and returned)

All users have the default password: `password123`

### 5. Access the application

- API: http://localhost:3000
- API Documentation (Swagger): http://localhost:3000/api-docs

## Development

### Running commands in the container

```bash
# Rails console
docker-compose exec web rails console

# Run migrations
docker-compose exec web rails db:migrate

# Run tests
docker-compose exec web rspec

# Run specific test file
docker-compose exec web rspec spec/models/user_spec.rb

# Generate migration
docker-compose exec web rails g migration AddColumnToTable

# Database reset (drops, creates, migrates, and seeds)
docker-compose exec web rails db:reset
```

### Stopping the application

```bash
# Stop containers
docker-compose down

# Stop and remove volumes (deletes database data)
docker-compose down -v
```

### Viewing logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web
docker-compose logs -f db
```

### Rebuilding after dependency changes

```bash
# Rebuild the web service
docker-compose up --build web
```

## Tech Stack

- **Ruby version**: 3.3.0
- **Rails version**: 7.2.0
- **Database**: PostgreSQL 15
- **Authentication**: Devise with JWT
- **Authorization**: Pundit
- **Serialization**: Active Model Serializers
- **API Documentation**: RSwag (Swagger/OpenAPI)
- **Testing**: RSpec, FactoryBot

## Project Structure

```
app/
├── controllers/     # API controllers
├── models/          # ActiveRecord models
├── policies/        # Pundit authorization policies
├── serializers/     # JSON serializers
└── services/        # Business logic services

spec/
├── controllers/     # Controller tests
├── models/          # Model tests
├── policies/        # Policy tests
├── requests/        # Integration tests
└── services/        # Service tests
```

## Running Tests

```bash
# Run all tests
docker-compose exec web rspec

# Run with coverage
docker-compose exec web rspec --format documentation

# Run specific test file
docker-compose exec web rspec spec/models/user_spec.rb

# Run specific test
docker-compose exec web rspec spec/models/user_spec.rb:10
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `DELETE /api/v1/auth/logout` - Logout

### Books
- `GET /api/v1/books` - List all books
- `GET /api/v1/books/:id` - Get book details
- `POST /api/v1/books` - Create book (librarian only)
- `PUT /api/v1/books/:id` - Update book (librarian only)
- `DELETE /api/v1/books/:id` - Delete book (librarian only)

### Borrowings
- `GET /api/v1/borrowings` - List borrowings
- `POST /api/v1/borrowings` - Borrow a book
- `PUT /api/v1/borrowings/:id/return` - Return a book

### Dashboard
- `GET /api/v1/dashboard` - Get dashboard statistics

For complete API documentation, visit http://localhost:3000/api-docs after starting the application.

## Troubleshooting

### Port already in use

If port 3000 or 5432 is already in use, update the ports in `docker-compose.yml`:

```yaml
services:
  web:
    ports:
      - "3001:3000"  # Change host port
  db:
    ports:
      - "5433:5432"  # Change host port
```

### Database connection issues

Ensure the database service is healthy:

```bash
docker-compose ps
```

If the database is not running, restart services:

```bash
docker-compose restart
```

### Permission issues

If you encounter permission issues with volumes:

```bash
sudo chown -R $USER:$USER .
```

## License

This project is available for use under the MIT License.
