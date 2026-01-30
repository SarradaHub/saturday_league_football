# Performance & Accessibility Enhancements

## Performance
- Added database indexes and `NOT NULL` constraints (`db/migrate/20251111000000_add_data_integrity_constraints.rb`) to reduce table scans and ensure consistent data.
- Introduced query/service layers to centralize eager loading and heavy computations, reducing N+1 risks. See [Architecture](architecture.md) for details on these layers.
- Enabled the Bullet gem in development to auto-detect inefficient queries via logs.

For test performance optimizations, see [Test Performance Optimizations](test-performance-optimizations.md).

## Accessibility
- Updated the PWA manifest to declare language, short name, categories, and high-contrast theme colors for better assistive technology support.
- Standardized API payloads through presenters/serializers to emit predictable fields, aiding downstream UI accessibility checks. See [Architecture](architecture.md) for details on the presentation layer.
- Documented accessibility expectations and testing hooks for future UI work.

