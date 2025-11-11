# Testing & CI

## Local Testing
- Ensure PostgreSQL is running (default creds `postgres` / `postgres`). Override via `PGHOST`, `PGUSER`, `PGPASSWORD`, `PGDATABASE[_TEST]`.
- Prepare the database before running specs: `bundle exec rails db:prepare`.
- Execute linters/tests locally:
  - `bundle exec rubocop`
  - `bundle exec rspec`

## Continuous Integration
- GitHub Actions workflow `.github/workflows/ci.yml` runs on pushes to `main` and pull requests.
- Workflow spins up PostgreSQL 16 service, installs dependencies, prepares the test DB, runs RuboCop, then RSpec.
- Coverage is collected via SimpleCov (output in `coverage/` on CI artifacts).

