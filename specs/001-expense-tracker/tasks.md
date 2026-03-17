# Tasks: Expense Tracker

**Input**: `specs/001-expense-tracker/plan.md`, `specs/001-expense-tracker/spec.md`
**Rails root**: `expense_tracker/` (created by `rails new` in Phase 1)
**Convention**: Each task maps to one of — create file, edit file, or run command.

## Format: `- [ ] [ID] [P?] [Story?] Description — file or command`

- **[P]**: Parallelisable (touches a different file, no unresolved dependency)
- **[US#]**: Belongs to a specific user story
- Commands are run from the Rails project root unless stated otherwise

---

## Phase 1: Setup

**Purpose**: Scaffold the Rails project, install dependencies, and configure tooling.

- [X] T001 Run `rails new expense_tracker --database=postgresql --css=tailwind` from parent directory to scaffold the project
- [X] T002 Edit `Gemfile` — add `devise`, `kaminari` under main gems; add `rspec-rails`, `factory_bot_rails`, `shoulda-matchers` to `group :development, :test`; add `bullet`, `rubocop-rails`, `rubocop-rspec` to `group :development`; add `capybara`, `selenium-webdriver` to `group :test`
- [X] T003 Run `bundle install` to install all gems
- [X] T004 Run `bundle exec rails generate rspec:install` to initialise RSpec (`spec/spec_helper.rb`, `spec/rails_helper.rb`, `.rspec`)
- [X] T005 [P] Edit `spec/rails_helper.rb` — enable `FactoryBot::Syntax::Methods`, configure `Shoulda::Matchers` for RSpec + Rails, set `config.use_transactional_fixtures = true`
- [X] T006 [P] Create `.rubocop.yml` at project root — inherit from `rubocop-rails` and `rubocop-rspec`, set `TargetRubyVersion: 3.1`, exclude `db/schema.rb` and `bin/`
- [X] T007 [P] Create `docker-compose.yml` at project root with a `db` service using `postgres:16` image, `POSTGRES_DB: expense_tracker_development`, `POSTGRES_USER: expense_tracker`, `POSTGRES_PASSWORD: password`, port mapping `5432:5432`, and named volume `postgres_data`
- [X] T008 [P] Edit `config/database.yml` — set `adapter: postgresql`, `host: <%= ENV.fetch("DB_HOST", "localhost") %>`, `port: <%= ENV.fetch("DB_PORT", 5432) %>`, `username: <%= ENV.fetch("DB_USERNAME", "expense_tracker") %>`, `password: <%= ENV.fetch("DB_PASSWORD", "password") %>` in the `default` anchor; set database names `expense_tracker_development`, `expense_tracker_test`, `expense_tracker_production`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Database, authentication, and base controller — every user story depends on these.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T009 Run `docker compose up -d db` to start the PostgreSQL container
- [X] T010 Run `bin/rails db:create` to create `expense_tracker_development` and `expense_tracker_test` databases
- [X] T011 Run `bin/rails generate devise:install` to install Devise and generate `config/initializers/devise.rb` and locale file
- [X] T012 Edit `config/environments/development.rb` — add `config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }` (required by Devise install output); also add Bullet configuration block: `config.after_initialize do Bullet.enable = true; Bullet.rails_logger = true; Bullet.raise = true end`
- [X] T013 Run `bin/rails generate devise User` to generate the User model and migration file
- [X] T014 If the generated `db/migrate/TIMESTAMP_devise_create_users.rb` is missing constraints or indexes, create a new migration to add `null: false, default: ""` to `email` and `encrypted_password`, and add `add_index :users, :email, unique: true`.
- [X] T015 Run `bin/rails db:migrate` to apply the Devise users migration
- [X] T016 Edit `app/models/user.rb` — add `has_many :categories, dependent: :destroy` and `has_many :transactions, dependent: :destroy` below the `devise` macro
- [X] T017 Edit `app/controllers/application_controller.rb` — add `before_action :authenticate_user!` so every action requires authentication by default
- [X] T018 Edit `config/routes.rb` — add `devise_for :users`; add `authenticated :user do root "dashboard#show", as: :authenticated_root end`; add `root "devise/sessions#new"`
- [X] T019 Run `bin/rails generate devise:views` to generate Devise view templates, then delete all generated subdirectories except `devise/sessions/` and `devise/registrations/`

**Checkpoint**: `bin/rails server` starts; visiting `/` redirects to sign-in; sign-up and sign-in flows work end-to-end.

---

## Phase 3: User Story 1 — User Account Management (Priority: P1) 🎯 MVP

**Goal**: A visitor can register and sign in; all protected URLs redirect unauthenticated requests to sign-in.

**Independent Test**: Register a new account → sign in → verify dashboard is accessible → sign out → verify `/transactions` redirects to sign-in.

- [X] T020 [US1] Edit `app/views/layouts/application.html.erb` — replace the default boilerplate with a full HTML5 layout that includes the Tailwind CDN/stylesheet link, a `<nav>` bar with links to Dashboard, Transactions, Categories, and a "Sign out" button (visible only when `user_signed_in?`), a flash message block, and `<%= yield %>`
- [X] T021 [US1] Edit `app/views/devise/sessions/new.html.erb` — replace generated content with a centred Tailwind card containing an email field, a password field, a "Sign in" submit button, and a link to the sign-up page
- [X] T022 [US1] Edit `app/views/devise/registrations/new.html.erb` — replace generated content with a centred Tailwind card containing an email field, password field, password-confirmation field, a "Create account" submit button, and a link to the sign-in page

**Checkpoint**: New user can register, sign in, see the (empty) root, and sign out. Unauthenticated `/transactions` redirects to sign-in.

---

## Phase 4: User Story 2 — Manage Categories (Priority: P2)

**Goal**: A signed-in user can create, rename, and delete their own categories; deletion is blocked when a category has transactions.

**Independent Test**: Create two categories → verify they appear in the list → rename one → confirm updated name → attempt to delete a category that has a transaction → confirm it is blocked.

	- [X] T023 [US2] Run `bin/rails generate model Category user:references name:string` to create the model and migration
	- [X] T024 [US2] If the generated `db/migrate/TIMESTAMP_create_categories.rb` is missing constraints or indexes, create a new migration to add `null: false` to `name`, ensure `t.references :user` has `null: false, foreign_key: true`, and add `add_index :categories, [:user_id, :name], unique: true`.
	- [X] T025 [US2] Run `bin/rails db:migrate` to apply the categories migration
	- [X] T026 [US2] Edit `app/models/category.rb` — add `has_many :transactions, dependent: :restrict_with_error`; add `validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }`; add `scope :for_user, ->(user) { where(user: user) }` and `scope :ordered, -> { order(:name) }`
	- [X] T027 [US2] Create `app/controllers/categories_controller.rb` — implement `index` (loads `current_user.categories.ordered`), `new`, `create`, `edit`, `update`, `destroy`; use `before_action :set_category, only: %i[edit update destroy]` where `set_category` does `current_user.categories.find(params[:id])`; in `destroy`, redirect with `alert` if the model has errors (from `restrict_with_error`); use private `category_params` with `permit(:name)`
	- [X] T028 [US2] Edit `config/routes.rb` — add `resources :categories` inside the authenticated scope or at the top level (before the closing `end`)
	- [X] T029 [US2] Create `app/views/categories/_form.html.erb` — a Tailwind form with a text input for `name` and a submit button; show `@category.errors.full_messages` at the top if any
	- [X] T030 [US2] Create `app/views/categories/index.html.erb` — a Tailwind table listing each category name with Edit and Delete links; a "New Category" button; show the flash `alert` if present (for restrict_with_error feedback)
	- [X] T031 [US2] Create `app/views/categories/new.html.erb` — page title "New Category" and render `form` partial
	- [X] T032 [US2] Create `app/views/categories/edit.html.erb` — page title "Edit Category" and render `form` partial

**Checkpoint**: Signed-in user can create, rename, and list categories. Attempting to delete a category that has transactions shows an error message instead.

---

## Phase 5: User Story 3 — Record a Transaction (Priority: P3)

**Goal**: A signed-in user can create, edit, and delete their own income/expense transactions.

**Independent Test**: Record one income and one expense transaction → verify both appear in the list with correct type and amount → edit one → delete one → confirm it is gone.

- [ ] T033 [US3] Run `bin/rails generate model Transaction user:references category:references amount:decimal{15,2} transaction_type:string transacted_on:date note:text` to create the model and migration
- [ ] T034 [US3] If the generated `db/migrate/TIMESTAMP_create_transactions.rb` is missing constraints or indexes, create a new migration to add `null: false` to `amount`, `transaction_type`, `transacted_on`, and both `references` columns; set `precision: 15, scale: 2` on `amount`; add the following indexes: `add_index :transactions, :user_id`, `add_index :transactions, :category_id`, `add_index :transactions, :transacted_on`, `add_index :transactions, [:user_id, :transacted_on]`; add `add_foreign_key :transactions, :users` and `add_foreign_key :transactions, :categories`.
- [ ] T035 [US3] Run `bin/rails db:migrate` to apply the transactions migration
- [ ] T036 [US3] Edit `app/models/transaction.rb` — define `TYPES = %w[income expense].freeze`; add associations `belongs_to :user` and `belongs_to :category`; add validations: `validates :amount, presence: true, numericality: { greater_than: 0 }`; `validates :transaction_type, inclusion: { in: TYPES }`; `validates :transacted_on, presence: true`; add scopes: `income`, `expense`, `in_period(start_date, end_date)`, `by_category(cat_id)`, `by_type(type)`, `recent` (orders by `transacted_on: :desc, id: :desc`)
- [ ] T037 [US3] Create `app/controllers/transactions_controller.rb` — implement `index`, `new`, `create`, `edit`, `update`, `destroy`; use `before_action :set_transaction, only: %i[edit update destroy]` where `set_transaction` does `current_user.transactions.find(params[:id])`; use private `transaction_params` permitting `:amount, :transaction_type, :transacted_on, :category_id, :note`; on `create`/`update` success redirect to `transactions_path` with `notice`; on failure re-render the form
- [ ] T038 [US3] Edit `config/routes.rb` — add `resources :transactions` (the `export_csv` collection route will be added in Phase 8)
- [ ] T039 [US3] Create `app/views/transactions/_form.html.erb` — Tailwind form with: a number input for `amount`, a date input for `transacted_on`, a select for `transaction_type` with options `[["Income", "income"], ["Expense", "expense"]]`, a collection select for `category_id` scoped to `current_user.categories.ordered`, a textarea for `note`, and a submit button; render `@transaction.errors.full_messages` at the top if any
- [ ] T040 [US3] Create `app/views/transactions/new.html.erb` — page title "New Transaction" and render `form` partial
- [ ] T041 [US3] Create `app/views/transactions/edit.html.erb` — page title "Edit Transaction" and render `form` partial

**Checkpoint**: Signed-in user can add income/expense transactions, edit them, and delete them. Accessing another user's transaction URL returns 404.

---

## Phase 6: User Story 4 — View & Filter Transaction List (Priority: P4)

**Goal**: A signed-in user can browse all their transactions in reverse-chronological order and narrow the list by date range, category, and/or type.

**Independent Test**: Record transactions across two months and two categories → apply each filter independently → confirm only matching rows are shown → apply two filters simultaneously → confirm intersection is returned → apply a filter with no matches → confirm empty-state message.

- [ ] T042 [US4] Edit `app/controllers/transactions_controller.rb` — add `index` action: start from `current_user.transactions.includes(:category).recent`; apply `in_period(params[:start_date], params[:end_date])` when both params are present; apply `by_category(params[:category_id])` when present; apply `by_type(params[:transaction_type])` when present; store result in `@transactions`; also assign `@categories = current_user.categories.ordered` for the filter dropdown
- [ ] T043 [US4] Create `app/views/transactions/index.html.erb` — a Tailwind filter bar (`<form method="get">`) with: a start-date input, end-date input, category select (include blank), type select (include blank), and a "Filter" submit button; a table showing `transacted_on`, `transaction_type`, `amount`, `category.name`, `note`, and Edit/Delete action links for each transaction; an empty-state `<p>` shown when `@transactions.empty?`; a "New Transaction" button at the top

**Checkpoint**: Transactions list shows all records by default; each filter type works independently and in combination; no other user's records appear.

---

## Phase 7: User Story 5 — Dashboard & Statistics (Priority: P5)

**Goal**: A signed-in user sees total income, total expenses, and net balance for the selected period (default: current month), plus a category expense breakdown.

**Independent Test**: Record a mix of income and expense transactions across two categories this month → open the dashboard → verify totals match manual arithmetic → switch to "Today" and "This Week" → verify totals change accordingly.

- [ ] T044 [US5] Create `app/services/dashboard_stats.rb` — define class `DashboardStats` with `initialize(user, start_date, end_date)` that builds `@scope = user.transactions.in_period(start_date, end_date)`; expose `total_income` (`@scope.income.sum(:amount)`), `total_expense` (`@scope.expense.sum(:amount)`), `net_balance` (`total_income - total_expense`), and `category_breakdown` (`@scope.expense.joins(:category).group("categories.name").order("sum_amount DESC").sum(:amount)`)
- [ ] T045 [US5] Create `app/controllers/dashboard_controller.rb` — implement `show` action: parse `params[:period]` (default `"this_month"`); compute `start_date` and `end_date` using a `period_range` private method that maps `"today"` → `Date.current..Date.current`, `"this_week"` → `Date.current.beginning_of_week..Date.current.end_of_week`, `"this_month"` → `Date.current.beginning_of_month..Date.current.end_of_month`; instantiate `@stats = DashboardStats.new(current_user, start_date, end_date)`; assign `@period = params[:period] || "this_month"`
- [ ] T046 [US5] Edit `config/routes.rb` — replace or confirm `resource :dashboard, only: [:show], controller: "dashboard"` and the `authenticated :user do root "dashboard#show" end` block are present
- [ ] T047 [US5] Create `app/views/dashboard/show.html.erb` — render three period-selector tab links (`Today`, `This Week`, `This Month`) as query-string links; three summary cards displaying `@stats.total_income`, `@stats.total_expense`, `@stats.net_balance` (formatted with `number_to_currency`); a category breakdown table iterating `@stats.category_breakdown` showing category name and expense total; show an empty-state message when `@stats.category_breakdown.empty?`

**Checkpoint**: Dashboard shows correct totals for each period; figures are zero when there are no transactions; only the signed-in user's data is shown.

---

## Phase 8: User Story 6 — Export Transactions to CSV (Priority: P6)

**Goal**: A signed-in user can download their (optionally filtered) transaction list as a CSV file.

**Independent Test**: Apply a date-range filter → click "Export CSV" → open the file → verify it contains only matching rows with correct headers (Date, Type, Amount, Category, Note).

- [ ] T048 [US6] Create `config/initializers/mime_types.rb` — add `Mime::Type.register "text/csv", :csv` so Rails recognises the CSV format in `respond_to` blocks
- [ ] T049 [US6] Edit `config/routes.rb` — nest a `collection` block inside `resources :transactions` with `get :export_csv`
- [ ] T050 [US6] Edit `app/controllers/transactions_controller.rb` — add private method `filtered_transactions` that extracts the shared filter logic from `index` (start_date, end_date, category_id, transaction_type) and returns a scope; refactor `index` to call `filtered_transactions`; add `export_csv` action: build the same filtered scope with `includes(:category)`; compute filename as `"transactions_#{params[:start_date] || "all"}_#{params[:end_date] || Date.current}.csv"`; use `respond_to format.csv` to set `Content-Disposition` header and render CSV string generated by a private `generate_csv(transactions)` method that uses Ruby's built-in `CSV` library with headers `["Date", "Type", "Amount", "Category", "Note"]`
- [ ] T051 [US6] Edit `app/views/transactions/index.html.erb` — add an "Export CSV" link below the filter bar that calls `export_csv_transactions_path(request.query_parameters)` with `data-turbo: false` so the browser triggers a file download

**Checkpoint**: Clicking "Export CSV" downloads a `.csv` file; filters applied on the page are reflected in the exported data; the file contains only the signed-in user's records.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Tests, linting, and final validation across all user stories.

- [ ] T052 [P] Create `spec/models/category_spec.rb` — test `validates :name, presence: true`; test uniqueness scoped to `user_id` (same name for different users is allowed); test `has_many :transactions, dependent: :restrict_with_error` (deletion blocked when transactions exist); test `scope :for_user` returns only the given user's categories
- [ ] T053 [P] Create `spec/models/transaction_spec.rb` — test `validates :amount` presence and `numericality greater_than: 0`; test `validates :transaction_type, inclusion: { in: %w[income expense] }`; test `validates :transacted_on` presence; test scopes `income`, `expense`, `in_period`, `by_category`, `by_type`, `recent`
- [ ] T054 [P] Create `spec/factories/users.rb`, `spec/factories/categories.rb`, `spec/factories/transactions.rb` — FactoryBot factories for each model with sensible defaults and traits (e.g., `trait :income`, `trait :expense` for Transaction)
- [ ] T055 [P] Create `spec/controllers/categories_controller_spec.rb` — test that unauthenticated requests to all actions redirect to sign-in; test that a user cannot access, edit, or delete another user's category (expect 404)
- [ ] T056 [P] Create `spec/controllers/transactions_controller_spec.rb` — test that unauthenticated requests redirect to sign-in; test that a signed-in user cannot access another user's transaction; test `index` applies each filter param correctly; test `export_csv` returns `text/csv` content type and correct headers
- [ ] T057 [P] Create `spec/system/user_authentication_spec.rb` — Capybara system spec: register a new account via the sign-up form; sign in; verify dashboard URL; sign out; verify redirect to sign-in; attempt to visit `/transactions` while signed out and confirm redirect
- [ ] T058 Run `bundle exec rubocop --autocorrect` from project root to auto-fix style offences, then review and resolve any remaining offences manually
- [ ] T059 Run `bin/rails spec` (or `bundle exec rspec`) to execute the full test suite and confirm all examples pass

---

## Dependencies & Execution Order

### Phase Dependencies

| Phase | Depends on | Notes |
|-------|-----------|-------|
| Phase 1 — Setup | — | Start immediately |
| Phase 2 — Foundational | Phase 1 complete | Blocks all user stories |
| Phase 3 — US1 Auth | Phase 2 complete | Layout + Devise views |
| Phase 4 — US2 Categories | Phase 3 complete | Categories must exist before Transactions |
| Phase 5 — US3 Transactions | Phase 4 complete | Transactions require a Category |
| Phase 6 — US4 Filter List | Phase 5 complete | Adds `index` action + view to Transactions |
| Phase 7 — US5 Dashboard | Phase 5 complete | Needs Transaction data and scopes |
| Phase 8 — US6 CSV Export | Phase 6 complete | Reuses the same filter logic as `index` |
| Phase 9 — Polish | All phases complete | Tests and linting |

### Story Dependencies (within Rails context)

- **US1 (Auth)**: Foundational; no story dependencies
- **US2 (Categories)**: Needs US1 (all routes are auth-protected)
- **US3 (Transactions)**: Needs US2 (Transaction requires a Category)
- **US4 (Filter List)**: Needs US3 (extends `TransactionsController#index`)
- **US5 (Dashboard)**: Needs US3 (reads Transaction data)
- **US6 (CSV Export)**: Needs US4 (reuses filter scope)

### Parallel Opportunities

Tasks marked **[P]** within the same phase touch different files and can be assigned to different agents/developers simultaneously:

| Phase | Parallel tasks |
|-------|---------------|
| Phase 1 | T005, T006, T007, T008 (after T003) |
| Phase 9 | T052, T053, T054, T055, T056, T057 |

---

## Implementation Strategy

### MVP Scope (User Story 1 Only)

1. Complete Phase 1 (Setup)
2. Complete Phase 2 (Foundational)
3. Complete Phase 3 (US1 — Auth)
4. **STOP and VALIDATE**: register, sign in, sign out, confirm unauthenticated redirect

### Incremental Delivery

| Increment | Phases | Deliverable |
|-----------|--------|-------------|
| 1 | 1 + 2 + 3 | Working auth — sign up, sign in, sign out |
| 2 | + 4 | Category management (CRUD) |
| 3 | + 5 | Transaction recording (CRUD) |
| 4 | + 6 | Filtered transaction list |
| 5 | + 7 | Dashboard with period statistics |
| 6 | + 8 | CSV export with active filters |
| 7 | + 9 | Tests pass, RuboCop clean |

Each increment is independently demonstrable without breaking the previous one.

---

## Notes for MCP Execution

- **File creation** tasks: use the filesystem MCP tool to write the full file content.
- **File edit** tasks: use the filesystem MCP tool to replace or patch the relevant section; always read the current file content first to avoid overwriting unrelated changes.
- **Command** tasks: use the shell/terminal MCP tool; run from the Rails project root unless stated otherwise.
- Commit after each phase checkpoint using `git add -A && git commit -m "Phase N: <description>"`.
- If a Rails generator creates a file that conflicts with a later "Create file" task, edit the generated file rather than overwriting it.
- `TIMESTAMP` in migration filenames is the actual timestamp generated by Rails; reference the file by its generated name after running the generator.
