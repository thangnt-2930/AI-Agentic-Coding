<!--
SYNC IMPACT REPORT
==================
Version change   : (none) → 1.0.0  (initial ratification)
Modified principles : N/A — first version
Added sections   :
  - Core Principles (8 principles)
  - Additional Constraints
  - Development Workflow
  - Governance
Removed sections : N/A
Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check gates aligned
  ✅ .specify/templates/spec-template.md — no mandatory section changes required
  ✅ .specify/templates/tasks-template.md — task categories reflect Rails MVC phases
Deferred TODOs   : none
-->

# Expense Tracker Constitution

## Core Principles

### I. Rails MVC Architecture (NON-NEGOTIABLE)

Expense Tracker MUST be built exclusively on the Rails MVC pattern with
server-side rendering via ERB. No separate frontend framework (React, Vue, etc.)
and no API-first approach are permitted.

- All business logic MUST reside in Models or dedicated Service Objects;
  Controllers MUST remain thin.
- Views MUST be ERB templates rendered by the server; JavaScript is limited
  to progressive enhancement (form validation, datepicker, chart rendering).
- Routes MUST follow RESTful conventions (`resources`, `member`, `collection`).
- No JSON API endpoints UNLESS serving an in-page AJAX partial for the same
  ERB view (e.g., dashboard chart data loaded asynchronously).

**Rationale**: A single rendering layer reduces complexity, keeps the team
aligned on one paradigm, and eliminates the maintenance burden of a
decoupled frontend build pipeline.

### II. Data Model Integrity

All persistent data MUST be defined through ActiveRecord migrations with
explicit constraints at both the database and model layers.

- Every schema change MUST be introduced through a dedicated Rails migration.
- Each logical schema modification MUST be implemented in a separate migration file.
- Direct modification of `schema.rb` or manual database alteration outside
  Rails migrations is strictly forbidden.
- Migrations MUST be generated using Rails generators (`rails generate migration`
  or `rails generate model`) rather than manually creating files.
- Every migration MUST include `null: false` constraints for required columns
  and appropriate `default:` values where applicable.
- Models MUST declare `validates` macros that mirror database constraints
  (presence, numericality, inclusion, uniqueness).
- `Transaction` MUST store `amount` as an integer (cents/đồng) or use a
  `decimal` column with precision ≥ 2 to avoid floating-point errors.
- `Transaction#transaction_type` MUST be limited to `["income", "expense"]`
  enforced by `validates :transaction_type, inclusion: { in: %w[income expense] }`.
- `Category` MUST be scoped per user (via `belongs_to :user`) to prevent
  data leakage between accounts.
- Database-level foreign keys MUST be declared for every `belongs_to`
  association (`add_foreign_key` in migrations).

**Rationale**: Dual-layer validation prevents inconsistent state regardless
of how data enters the system (seeds, console, API, form).

### III. Thin Controllers, Fat Models

Controllers MUST only orchestrate: authenticate, authorize, call model/service,
set flash, redirect or render. No business logic in controllers.

- Each controller action MUST NOT exceed ~15 lines of meaningful code.
- Query logic that spans multiple tables or requires grouping/aggregation
  MUST be extracted to a scope, class method, or Service Object.
- Permitted parameters MUST be declared via `params.require(...).permit(...)`
  in a private `*_params` method — never inline.
- Before-filters (`before_action`) MUST be used for authentication checks
  and resource loading; they MUST NOT contain business computations.

**Rationale**: Keeping controllers thin ensures testability of business logic
in isolation and prevents controllers from becoming unmaintainable god objects.

### IV. Transaction & Category Business Rules

All financial logic MUST be consistent and auditable.

- A `Transaction` MUST belong to exactly one `User` and exactly one `Category`.
- `Category` deletion MUST be blocked if associated Transactions exist
  (`has_many :transactions` with `restrict_with_error` or equivalent).
- `amount` MUST always be stored as a positive value; the sign semantics are
  carried by `transaction_type` (`income` / `expense`).
- Date of transaction (`transacted_on` or `date`) MUST be a `date` column
  (not `datetime`) since time-of-day is not relevant to financial reporting.
- Soft-delete is NOT required for MVP; hard-delete with cascading is acceptable
  provided the user owns the record.
- Authorization: a user MUST only be able to read/modify their own
  Transactions and Categories — enforced in every controller action.

**Rationale**: Strict ownership and type rules prevent financial
miscalculations and cross-user data exposure.

### V. Dashboard & Reporting

Dashboard data MUST be accurate, scoped to the authenticated user, and
performant for up to 10,000 transactions per user.

- Summary totals (total income, total expense, net balance) MUST be computed
  via `SUM` SQL aggregates — never by loading records into Ruby memory.
- Period filters (daily / weekly / monthly) MUST map to explicit date ranges
  passed to ActiveRecord scopes; default period is the current month.
- Chart data MUST be serialised server-side and embedded in the ERB template
  (e.g., as a JSON data attribute) rather than fetched via a separate API call,
  unless lazy loading is explicitly required for UX reasons.
- Category breakdown MUST use `GROUP BY category_id` at the database level.
- All dashboard queries MUST include the user scope first:
  `current_user.transactions.where(...)`.

**Rationale**: Aggregate queries keep memory usage flat regardless of
transaction volume and ensure figures are always consistent with the database.

### VI. CSV Export

Export functionality MUST be deterministic, scoped, and streamed for large
datasets.

- CSV generation MUST use Ruby's built-in `CSV` library — no third-party gem
  required for basic export.
- Exported records MUST respect the same filter parameters (date range,
  category, type) as the current list view.
- Column headers MUST be human-readable English labels, not raw attribute names.
- The exported filename MUST include the user identifier and date range,
  e.g., `transactions_2026-01-01_2026-03-13.csv`.
- For datasets potentially exceeding 5,000 rows, streaming response
  (`response.stream`) MUST be used to avoid memory spikes.
- CSV export MUST NOT expose any column that belongs to another user.

**Rationale**: Predictable, filtered export builds user trust and keeps
memory consumption bounded.

### VII. Performance — N+1 Prevention (NON-NEGOTIABLE)

No query that loads a collection of records is permitted to trigger per-record
additional queries.

- Every `index` action and every dashboard query MUST use `includes`,
  `preload`, or `eager_load` for all associations rendered in the view.
- The Bullet gem (or equivalent) MUST be enabled in the `development`
  environment and configured to raise on N+1 detection.
- Scopes that are reused across controllers MUST be defined on the model with
  explicit `includes` where applicable.
- Database columns used in `WHERE`, `ORDER BY`, or `GROUP BY` clauses MUST
  have database indexes declared in the migration.
- `counter_cache` SHOULD be used on `Category#transactions_count` if the
  count is displayed in list views.

**Rationale**: N+1 queries are the single most common Rails performance
failure; catching them at development time prevents production degradation.

### VIII. Rails Code Standards & Conventions

All code MUST follow community Rails conventions to ensure consistency and
maintainability.

- Follow the [Rails Style Guide](https://rails.rubystyle.guide/) and enforce
  it with RuboCop (`rubocop-rails` extension) in CI.
- File naming MUST match Rails conventions: `snake_case` for files,
  `CamelCase` for classes, plural for controllers and table names.
- Helper methods used across multiple views MUST be placed in
  `ApplicationHelper` or a dedicated feature helper — not in controllers.
- Partials MUST be used for repeated view fragments (e.g., transaction row,
  form fields); partials MUST be prefixed with `_`.
- Time/date display MUST go through I18n helpers (`l(date, format: :short)`)
  to support future localisation.
- Secrets and credentials MUST be managed via `config/credentials.yml.enc`;
  no secrets in source code or `.env` files committed to the repository.
- Test coverage MUST include model validations, scopes, and controller
  authorization using RSpec + FactoryBot; system specs (Capybara) for
  critical user flows (create transaction, view dashboard, export CSV).

**Rationale**: Uniform conventions lower the onboarding cost for new
developers and make code review predictable.

## Additional Constraints

**Technology Stack**:
- Language: Ruby (≥ 3.1) with Ruby on Rails (≥ 7.1)
- Database: PostgreSQL (recommended) or SQLite for development
- View layer: ERB templates only; Tailwind CSS or Bootstrap for styling
- JavaScript: Stimulus (Hotwire) for lightweight interactivity; no heavy SPA
- Testing: RSpec, FactoryBot, Capybara, Shoulda-Matchers
- Linting: RuboCop with `rubocop-rails` and `rubocop-rspec`
- Background jobs: NOT required for MVP; Sidekiq may be added for async CSV
  export if dataset grows beyond 10,000 rows

**Security Constraints**:
- Authentication MUST be implemented via Devise or a hand-rolled
  `SessionsController`; no unauthenticated access to any transaction route.
- CSRF protection MUST remain enabled (Rails default); never call
  `protect_from_forgery` with `:null_session` on non-API controllers.
- Mass assignment MUST be prevented via Strong Parameters on every controller.

**Deployment**:
- The app MUST run correctly on a single Heroku dyno or equivalent PaaS for
  MVP; horizontal scaling is out of scope.

## Development Workflow

**Constitution Check** (MUST pass before any feature branch is merged):

1. No business logic resides in a Controller or View.
2. All new associations include database-level foreign keys.
3. Collection queries are verified N+1-free (Bullet log reviewed).
4. RuboCop reports zero offences on changed files.
5. New dashboard queries use SQL aggregates, not Ruby enumeration.
6. CSV export respects current filter scope and ownership check.
7. RSpec coverage for model validations and controller authorization added.

**Review Process**:
- Every PR requires at least one peer review before merge.
- PR description MUST reference the principle(s) exercised or relaxed, with
  justification if a principle is relaxed.
- Performance-sensitive changes (dashboard, export) MUST include a `EXPLAIN
  ANALYZE` snippet or Bullet output in the PR description.

**Amendment Procedure**:
- Any change to a principle requires a PR targeting `main` with the updated
  constitution, a description of the impact, and team consensus (≥ 2 approvals).
- Version MUST be bumped according to semantic versioning rules defined in
  the Governance section below.

## Governance

This constitution supersedes all other architectural guidance for the Expense
Tracker project. In case of conflict between this document and any other
guide, wiki page, or verbal agreement, this constitution takes precedence.

**Versioning Policy**:
- MAJOR bump: backward-incompatible principle removal or redefinition (e.g.,
  switching from MVC to API-first).
- MINOR bump: new principle added or existing principle materially expanded.
- PATCH bump: clarification, wording fix, or non-semantic refinement.

**Compliance Review**: The constitution MUST be reviewed at the start of each
project milestone (or every 3 months, whichever comes first) to confirm it
remains aligned with actual practice.

All pull requests and code reviews MUST verify compliance with the principles
above. Non-compliant code MUST be rejected and revised before merge.

## Step-by-step Process for Each Task

For every task defined in `tasks.md`, the following workflow MUST be followed:

- [ ] 1. Checkout the latest `main` branch
- [ ] 2. Create a new branch for the task (`feature/<task-name>` or `fix/<task-name>`)
- [ ] 3. Implement the task according to the specification
- [ ] 4. Run tests and ensure RuboCop passes
- [ ] 5. Mark the task as **done in `tasks.md`** after the implementation is merged
- [ ] 6. Commit the changes with a clear commit message
- [ ] 7. Push the branch to GitHub
- [ ] 8. Create a Pull Request targeting `main`
- [ ] 9. Wait for review and merge approval

**Rule**: The next task MUST NOT be started until the previous task's Pull Request has been merged into `main`.

**Version**: 1.0.0 | **Ratified**: 2026-03-13 | **Last Amended**: 2026-03-13
