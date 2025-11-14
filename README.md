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
- Lint the codebase with `bin/rubocop`.
- Security scans are available through `bin/brakeman`.

## Deployment

Deployment is automated with Kamal. Review `config/deploy.yml` for server information and ensure the target hosts expose PostgreSQL and Redis as required services.
