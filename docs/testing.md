# Testing Guide

## Introduction

This guide covers testing practices for the Saturday League Football application. We use RSpec as our testing framework and aim for **80% code coverage** as a baseline. However, coverage is a tool to find gaps, not the only measure of test quality.

### Why Testing Matters

- **Confidence**: Tests give us confidence that our code works as expected
- **Documentation**: Tests serve as living documentation of how the code behaves
- **Refactoring Safety**: Good tests allow us to refactor with confidence
- **Bug Prevention**: Tests catch bugs before they reach production
- **API Contract Validation**: Tests ensure API endpoints maintain their contracts

### Coverage Goals

Our target is **80% code coverage**, but remember:
- **80% is a starting point**, not an end goal
- **Coverage shows what's NOT tested**, not what IS tested well
- **Prioritize critical paths** over achieving 100% coverage
- **Test behavior, not implementation** - high coverage with poor tests is worse than lower coverage with good tests

## Running Tests

### Basic Commands

```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/player_spec.rb

# Run specific test
bundle exec rspec spec/models/player_spec.rb:10

# Run tests with documentation format
bundle exec rspec --format documentation

# Run tests in watch mode (requires guard or similar)
bundle exec rspec --watch
```

### Database Setup

Before running tests, ensure PostgreSQL is running and the test database is prepared:

```bash
# Set database credentials (if different from defaults)
# Default credentials: postgres / postgres
export PGHOST=localhost
export PGUSER=postgres
export PGPASSWORD=postgres
export PGDATABASE_TEST=saturday_league_football_test

# Prepare the test database
bundle exec rails db:prepare
```

### Docker Workflow

```bash
# Run tests in Docker container
docker-compose -f docker-compose.test.yml run --rm test bundle exec rspec
```

### Running Linters

Before running tests, you may want to check code style:

```bash
# Run RuboCop for code style checks
bundle exec rubocop
```

## Coverage Reports

### Generating Coverage Reports

Coverage is automatically generated when running tests. After running tests, you can view the coverage report:

```bash
# Open HTML coverage report
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

### Understanding Coverage Reports

The coverage report shows:
- **Line Coverage**: Percentage of lines executed
- **Branch Coverage**: Percentage of branches (if/else, case) executed
- **File-by-file breakdown**: See which files need more tests
- **Grouped by type**: Controllers, Models, Services, Presenters, Policies, Queries, Serializers

### Coverage Thresholds

Our coverage configuration enforces:
- **Minimum 80% overall coverage**
- **Minimum 80% per-file coverage**

If coverage falls below these thresholds, the test suite will fail.

## Writing Tests

### Test Structure

RSpec uses `describe`, `context`, and `it` blocks to organize tests:

```ruby
require 'rails_helper'

RSpec.describe Player, type: :model do
  describe 'associations' do
    it 'belongs to a team' do
      # test code
    end
  end

  context 'with valid attributes' do
    it 'saves successfully' do
      # test code
    end
  end
end
```

### Model Tests

Test models for:
- **Associations**: `belongs_to`, `has_many`, etc.
- **Validations**: Required fields, format validations
- **Methods**: Business logic, calculations
- **Scopes**: Query methods

Example:

```ruby
RSpec.describe Player, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:player_stats) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:team_id) }
  end
end
```

### Controller Tests

Test controllers for:
- **HTTP responses**: Status codes, redirects
- **Authentication/Authorization**: Access control
- **Data handling**: Params, JSON responses
- **Rendering**: JSON responses

Example:

```ruby
RSpec.describe Api::V1::ChampionshipsController, type: :controller do
  describe 'GET #index' do
    it 'returns a success response' do
      get :index, format: :json
      expect(response).to be_successful
    end

    it 'returns championships as JSON' do
      championship = create(:championship)
      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
    end
  end
end
```

### Service Tests

Test services for:
- **Business logic**: Core functionality
- **Error handling**: Edge cases, invalid inputs
- **Side effects**: Database changes, calculations

Example:

```ruby
RSpec.describe Players::MatchStatistics do
  subject(:call_result) do
    described_class.call(player: player, team: team, round: round, match: match)
  end

  let(:player) { create(:player) }
  let(:team) { create(:team) }
  let(:round) { create(:round, :with_championship) }
  let(:match) { create(:match, round: round, team_1: team, team_2: create(:team)) }

  before do
    team.players << player
    create(:player_stat, player: player, team: team, match: match, goals: 1, assists: 2)
  end

  it 'aggregates match totals' do
    expect(call_result).to include(
      goals_in_match: 1,
      assists_in_match: 2,
      own_goals_in_match: 0
    )
  end
end
```

### Presenter Tests

Test presenters for:
- **Data transformation**: How data is formatted
- **View logic**: Calculations for display
- **Conditional rendering**: Different states

Example:

```ruby
RSpec.describe MatchPresenter do
  let(:match) { create(:match) }
  let(:presenter) { described_class.new(match) }

  describe '#score_display' do
    it 'formats the score correctly' do
      match.update(team_1_score: 2, team_2_score: 1)
      expect(presenter.score_display).to eq('2 - 1')
    end
  end
end
```

### Policy Tests

Test policies for:
- **Authorization rules**: Who can access what
- **Permission checks**: Different user roles
- **Scope methods**: Filtered data access

### Query Tests

Test query objects for:
- **Filtering**: Correct data selection
- **Sorting**: Order of results
- **Pagination**: Page size and offset

### Serializer Tests

Test serializers for:
- **JSON structure**: Correct attributes
- **Relationships**: Nested data
- **Conditional attributes**: Different contexts

### Using Factories (FactoryBot)

We use FactoryBot for test data. Factories are defined in `spec/factories/`:

```ruby
# Create a player
player = create(:player)

# Create with attributes
player = create(:player, name: 'John Doe', team: team)

# Create with traits
round = create(:round, :with_championship)

# Build without saving
player = build(:player)

# Create multiple
players = create_list(:player, 3)
```

### Using Shoulda Matchers

We use Shoulda Matchers for concise association and validation tests:

```ruby
RSpec.describe Player, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:team) }
    it { is_expected.to have_many(:player_stats) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:age).is_greater_than(0) }
  end
end
```

## Best Practices

### 1. Test Behavior, Not Implementation

**Bad:**
```ruby
it 'calls the calculate method' do
  expect(player).to receive(:calculate)
  player.process
end
```

**Good:**
```ruby
it 'calculates the correct statistics' do
  player = create(:player)
  create(:player_stat, player: player, goals: 2)
  stats = Players::MatchStatistics.call(player: player, team: team, round: round, match: match)
  expect(stats[:goals_in_match]).to eq(2)
end
```

### 2. Use Descriptive Test Names

**Bad:**
```ruby
it 'works' do
```

**Good:**
```ruby
it 'aggregates match totals correctly' do
```

### 3. Test Edge Cases

Always test:
- **Empty/nil values**
- **Boundary conditions**
- **Invalid inputs**
- **Error conditions**

Example:

```ruby
describe 'edge cases' do
  it 'handles player with no stats' do
    player = create(:player)
    stats = Players::MatchStatistics.call(player: player, team: team, round: round, match: match)
    expect(stats[:goals_in_match]).to eq(0)
  end

  it 'handles nil values gracefully' do
    expect { described_class.call(player: nil, team: team, round: round, match: match) }
      .to raise_error(ArgumentError)
  end
end
```

### 4. Keep Tests Independent

Each test should be able to run in isolation:
- Use `let` and `before` for setup
- Use transactional fixtures (enabled by default)
- Don't rely on test execution order

### 5. Use Appropriate Test Types

- **Unit tests**: Fast, test individual components (models, services, presenters)
- **Integration tests**: Test component interactions (controllers with database)
- **System tests**: Test full user workflows (if applicable)

### 6. Focus on Critical Paths

Prioritize testing:
- **Business-critical functionality**: Match statistics, scoring
- **User-facing features**: API endpoints
- **Complex calculations**: Statistics, aggregations
- **Error-prone areas**: Data transformations

### 7. Use Subject and Let

Use `subject` for the main object under test and `let` for dependencies:

```ruby
RSpec.describe Players::MatchStatistics do
  subject(:call_result) do
    described_class.call(player: player, team: team, round: round, match: match)
  end

  let(:player) { create(:player) }
  let(:team) { create(:team) }
  let(:round) { create(:round, :with_championship) }
  let(:match) { create(:match, round: round, team_1: team, team_2: create(:team)) }
end
```

## Coverage Best Practices

Based on [Google's Code Coverage Best Practices](https://testing.googleblog.com/2020/08/code-coverage-best-practices.html):

1. **Use coverage to find gaps**: Coverage tells you what's NOT tested, not what IS tested well
2. **Don't chase 100%**: Some code (like error handlers) may not need full coverage
3. **Focus on meaningful coverage**: Test critical paths and edge cases
4. **Avoid testing implementation details**: Test behavior, not how it's implemented
5. **Use coverage as a guide**: It's one metric among many

## CI Integration

### GitHub Actions

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs automatically on pushes to `main` and pull requests. The workflow:
1. Sets up Ruby and PostgreSQL 16
2. Installs dependencies
3. Prepares the test database
4. Runs RuboCop for code style
5. Runs RSpec with coverage
6. Uploads coverage artifacts

Coverage is automatically generated in CI via SimpleCov (output in `coverage/` directory).

### Viewing CI Coverage

Coverage reports are available as CI artifacts. Download and open `coverage/index.html` to view the report.

## Troubleshooting

### Tests Fail with Coverage Below 80%

1. Check which files have low coverage
2. Review the coverage report: `open coverage/index.html`
3. Add tests for uncovered code
4. Consider if the code should be excluded (add to SimpleCov filters)

### Database Issues

```bash
# Reset test database
RAILS_ENV=test bundle exec rails db:reset

# Or prepare fresh
RAILS_ENV=test bundle exec rails db:prepare
```

### PostgreSQL Connection Issues

Ensure PostgreSQL is running and credentials are correct:

```bash
# Check PostgreSQL is running
pg_isready

# Test connection
psql -U postgres -d saturday_league_football_test -c "SELECT 1;"
```

### Slow Tests

- Use `let` instead of `let!` when possible
- Avoid unnecessary database queries
- Use `build` instead of `create` when you don't need persistence
- Consider using `build_stubbed` for read-only tests

For detailed information on test performance optimizations, see [Test Performance Optimizations](test-performance-optimizations.md).

### Coverage Not Generating

- Ensure SimpleCov is required at the top of `spec_helper.rb`
- Check that `coverage/` directory is not in `.gitignore` (it should be)
- Verify SimpleCov gem is in the Gemfile

### Factory Issues

```bash
# Check factory definitions
bundle exec rails console
FactoryBot.factories.each { |f| puts f.name }
```

## Application-Specific Testing

### Testing Match Statistics

When testing match statistics services:
- Test aggregation across multiple matches
- Test filtering by team, round, or player
- Test edge cases (no stats, single stat, multiple stats)

### Testing API Endpoints

When testing API controllers:
- Test JSON responses
- Test error handling
- Test authentication/authorization (if applicable)
- Test pagination (if applicable)

### Testing Presenters

When testing presenters:
- Test data formatting
- Test conditional logic
- Test calculations for display

## Resources

- [RSpec Documentation](https://rspec.info/)
- [RSpec Rails Guide](https://rspec.info/documentation/rails/)
- [SimpleCov Documentation](https://github.com/simplecov-ruby/simplecov)
- [FactoryBot Documentation](https://github.com/thoughtbot/factory_bot)
- [Shoulda Matchers Documentation](https://github.com/thoughtbot/shoulda-matchers)
- [Google Testing Blog - Code Coverage Best Practices](https://testing.googleblog.com/2020/08/code-coverage-best-practices.html)

## Questions?

If you have questions about testing or need help writing tests, reach out to the team or check the existing test files for examples.

