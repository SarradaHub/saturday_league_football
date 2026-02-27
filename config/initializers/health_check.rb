HealthCheck.setup do |config|
  # URI base (sem barra inicial), conforme README da gem:
  # https://github.com/Purple-Devs/health_check
  config.uri = 'health_check'

  # Textos padrão de sucesso/erro
  config.success = 'success'
  config.failure = 'health_check failed'

  # Não incluir mensagem de erro detalhada no body por padrão
  # para evitar vazamento de informações sensíveis.
  config.include_error_in_response_body = false

  # Status HTTP quando a resposta é texto simples ou objeto (JSON/XML)
  config.http_status_for_error_text = 500
  config.http_status_for_error_object = 500

  # Checks padrão: focar em app + banco/migrations.
  # (Outros como cache/redis/s3 podem ser ligados depois, se usados.)
  config.standard_checks = %w[database migrations site]

  # Checks completos (para /health_check/all)
  config.full_checks = %w[database migrations site]

  # Restringir custo dos checks em ambientes com monitoramento frequente
  config.max_age = 1
end

