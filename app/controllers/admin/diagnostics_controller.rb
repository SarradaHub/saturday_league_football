class Admin::DiagnosticsController < ApplicationController
  def migrations
    context = ActiveRecord::Base.connection.migration_context
    statuses = context.migrations_status

    pending = statuses.select { |state, _version, _name| state == 'down' }
    applied = statuses.select { |state, _version, _name| state == 'up' }

    render json: {
      pending_count: pending.size,
      applied_count: applied.size,
      pending: pending.map { |_state, version, name| { version:, name: } },
      applied: applied.map { |_state, version, name| { version:, name: } }
    }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
