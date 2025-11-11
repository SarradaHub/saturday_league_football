# Architecture Overview

## Layers
- **Controllers** (`app/controllers/api`): Thin HTTP adapters inheriting from `Api::BaseController`, focused on orchestration and serialization.
- **Services** (`app/services`): Command-style objects invoked via `.call` for business workflows and side-effect orchestration.
- **Queries** (`app/queries`): Read-model helpers encapsulating complex ActiveRecord queries.
- **Presenters** (`app/presenters`): View-facing decorators to prepare data for serialization.
- **Serializers** (`app/serializers`): Responsible for shaping API payloads independently of ActiveRecord models.
- **Policies** (`app/policies`): Authorization boundaries (stubbed for future expansion).

## Autoloading
- `config/application.rb` loads each layer via Zeitwerk to keep naming conventions and autoloading consistent.

## Next Steps
- Migrate heavy model/controller logic into dedicated services, queries, and presenters.
- Add policy/authorization rules once requirements are defined.
- Adopt consistent serializer objects and update controllers to render them.

