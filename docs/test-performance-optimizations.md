# Otimizações de Performance dos Testes

> For general testing information, see [Testing Guide](testing.md).

## Problemas Identificados

1. **Delete operations em cada teste**: O `paginatable_spec.rb` estava executando `delete_all` antes de cada teste (23 vezes), causando lentidão extrema.
2. **SimpleCov sempre ativo**: Adiciona overhead significativo em todos os testes.
3. **Falta de profile de testes lentos**: Não havia como identificar quais testes eram mais lentos.

## Otimizações Implementadas

### 1. Otimização do `paginatable_spec.rb`
- **Antes**: `delete_all` executado 23 vezes (uma vez por teste)
- **Depois**: `delete_all` executado apenas 1 vez no `before(:all)`, confiando em transactional fixtures para isolamento
- **Ganho estimado**: Redução de ~95% no tempo de setup deste arquivo

### 2. SimpleCov Condicional
- **Antes**: SimpleCov sempre ativo, adicionando overhead em todos os testes
- **Depois**: SimpleCov só inicia se `COVERAGE` ou `CI` estiverem definidos
- **Uso**: 
  ```bash
  # Para rodar com coverage
  COVERAGE=1 bundle exec rspec
  
  # Para rodar sem coverage (mais rápido)
  bundle exec rspec
  ```

### 3. Profile de Testes Lentos
- Habilitado `config.profile_examples = 10` para identificar os 10 testes mais lentos
- Isso ajuda a identificar outros gargalos no futuro

## Recomendações Adicionais

### 1. Paralelização (Recomendado)
Para reduzir ainda mais o tempo de execução, considere usar `parallel_tests`:

```ruby
# Gemfile
gem 'parallel_tests', group: :test

# Configuração
bundle install
bundle exec rake parallel:create
bundle exec rake parallel:migrate

# Executar testes em paralelo
bundle exec rake parallel:spec
```

**Ganho esperado**: Redução de 50-70% no tempo total (dependendo do número de CPUs)

### 2. Database Cleaner (Opcional)
Se você encontrar problemas com transactional fixtures, considere usar `database_cleaner`:

```ruby
# Gemfile
gem 'database_cleaner-active_record', group: :test

# spec/support/database_cleaner.rb
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

### 3. Factory Bot Optimization
Considere usar `build_stubbed` quando possível (mais rápido que `create`):

```ruby
# Mais rápido - não persiste no banco
let(:user) { build_stubbed(:user) }

# Mais lento - persiste no banco
let(:user) { create(:user) }
```

### 4. Evitar N+1 Queries em Testes
Use `includes` e `preload` nos testes também:

```ruby
# Ruim - N+1 queries
let(:teams) { Team.all }
teams.each { |team| team.players.count }

# Bom - 1 query
let(:teams) { Team.includes(:players).all }
teams.each { |team| team.players.count }
```

### 5. Testes de Integração
Considere separar testes rápidos (unitários) dos lentos (integração):

```bash
# Apenas testes rápidos
bundle exec rspec --tag ~slow

# Apenas testes lentos
bundle exec rspec --tag slow
```

## Métricas Esperadas

Com as otimizações implementadas:
- **Antes**: ~25-26 minutos
- **Depois (estimado)**: ~15-18 minutos (sem coverage)
- **Com paralelização**: ~8-10 minutos (4 CPUs)

## Monitoramento

Execute periodicamente com profile para identificar novos gargalos:

```bash
bundle exec rspec --profile
```

Isso mostrará os 10 testes mais lentos e ajudará a identificar problemas futuros.
