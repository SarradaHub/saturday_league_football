# Saturday League Football

Saturday League Football is a Rails 8 application that manages a local football championship. It helps organizers register teams, maintain rosters, schedule rounds, record matches, and track player statistics across the season.

## Core Capabilities

- Register teams and manage player assignments through `PlayerTeam`.
- Create championship rounds and schedule matches between registered teams.
- Capture player level stats per round and match, including goals and attendance.
- Provide JSON APIs that client applications can consume for standings and fixtures.
- Ship with background job infrastructure using Solid Queue, Solid Cache, and Turbo streams for real time dashboards.

## Domain Overview

- `Championship` groups the season, rounds, and teams.
- `Round` is a matchday containing one or more `Match` records.
- `Player` connects to multiple teams and accumulates `PlayerStat` entries.
- `PlayerRound` stores availability and performance notes for each player in a given round.

## Getting Started

1. Install dependencies:
   ```bash
   bundle install
   npm install
   ```
2. Configure environment variables by copying `.env.example` to `.env` and adjusting values.
3. Prepare the database:
   ```bash
   bin/rails db:create db:migrate db:seed
   ```
4. Start the application:
   ```bash
   ./bin/dev
   ```

The app runs on `http://localhost:3000` with Rails server, Vite, and background workers managed by Foreman.

## Testing and Quality

- Run tests with `bin/rspec`.
- Run latency checks with `PERF_SPECS=1 bin/rspec spec/performance/latency_spec.rb`.
- Generate API reference with `bin/rails api_docs:generate` (updates `docs/api_reference.md`).
- Lint the codebase with `bin/rubocop`.
- Security scans are available through `bin/brakeman`.

## Deployment

Deployment is automated with Kamal. Review `config/deploy.yml` for server information and ensure the target hosts expose PostgreSQL and Redis as required services.

## GitHub Actions & Required Checks

The repository ships with several GitHub Actions workflows under `.github/workflows`:

- `ci.yml` (`rails-ci` job): runs the full Rails test suite and should be marked as **required** on protected branches.
- `coverage-badge.yml` (`coverage` job): generates and commits the coverage badge; it can optionally be marked as **required** to enforce coverage runs on `main`/`develop`.
- `security.yml` (`security` job): runs security scans (CodeQL, dependency audit, secret scan) and is recommended as a **required** check.

To configure required checks on GitHub:

1. Go to **Settings → Branches → Branch protection rules**.
2. Edit (or create) the rule for `main` (and `develop`, if applicable).
3. Enable **“Require status checks to pass before merging”**.
4. Add the following checks by their job names:
   - `rails-ci`
   - `coverage`
   - `security`
5. Save the rule.
