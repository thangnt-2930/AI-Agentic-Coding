# Implementation Plan: Expense Tracker

**Feature Branch**: `001-expense-tracker`
**Created**: 2026-03-13
**Status**: Draft

---

## 1. Overall Architecture

The application follows a classic **Ruby on Rails MVC** pattern with
server-side rendering. There is no separate frontend framework and no JSON API
layer.

```
Browser
  │  HTTP request / form submission
  ▼
Rails Router
  │  matches route → controller#action
  ▼
Controller (thin — orchestrate only)
  │  calls model / service
  ▼
Model / Service Object (business logic, queries)
  │  ActiveRecord ↔ PostgreSQL
  ▼
View (ERB template)
  │  returns HTML
  ▼
Browser
```

**Stack**:
- Language: Ruby ≥ 3.1
- Framework: Ruby on Rails ≥ 7.1
- View layer: ERB + Tailwind CSS (utility-first styling)
- JavaScript: Stimulus (Hotwire) — progressive enhancement only
- Database: PostgreSQL (runs in Docker)
- Authentication: Devise
- Testing: RSpec, FactoryBot, Capybara, Shoulda-Matchers
- Linting: RuboCop (`rubocop-rails`, `rubocop-rspec`)
- N+1 detection: Bullet gem (development only)

---

## 2. Docker Setup for PostgreSQL

A `docker-compose.yml` at the project root manages the database container.
The Rails application connects to it via `config/database.yml`.

### `docker-compose.yml`

```yaml
version: "3.9"

services:
  db:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: expense_tracker_development
      POSTGRES_USER: expense_tracker
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Key points**:
- Port `5432` is mapped to the host so the Rails process (running locally or
  in another container) can reach it.
- `postgres_data` volume persists data across container restarts.
- Credentials are set as environment variables; Rails reads them from
  `database.yml` (which references ENV vars or Rails credentials).

---

## 3. Rails Database Configuration

### `config/database.yml`

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  host: <%= ENV.fetch("DB_HOST", "localhost") %>
  port: <%= ENV.fetch("DB_PORT", 5432) %>
  username: <%= ENV.fetch("DB_USERNAME", "expense_tracker") %>
  password: <%= ENV.fetch("DB_PASSWORD", "password") %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>

development:
  <<: *default
  database: expense_tracker_development

test:
  <<: *default
  database: expense_tracker_test

production:
  <<: *default
  database: expense_tracker_production
  username: <%= ENV["DB_USERNAME"] %>
  password: <%= ENV["DB_PASSWORD"] %>
```

Environment variables are used so secrets are never hard-coded. For
production, values come from the deployment environment or
`config/credentials.yml.enc`.

---

## 4. Database Design

### Entity Relationship

```
users
  │ has_many :categories
  │ has_many :transactions
  │
  ├── categories
  │     belongs_to :user
  │     has_many   :transactions  (restrict_with_error on delete)
  │
  └── transactions
        belongs_to :user
        belongs_to :category
```

### Table: `users`

Managed by Devise. Core columns created by the Devise generator.

| Column             | Type     | Constraints               |
|--------------------|----------|---------------------------|
| id                 | bigint   | PK                        |
| email              | string   | NOT NULL, UNIQUE          |
| encrypted_password | string   | NOT NULL                  |
| created_at         | datetime | NOT NULL                  |
| updated_at         | datetime | NOT NULL                  |

### Table: `categories`

| Column     | Type    | Constraints              |
|------------|---------|--------------------------|
| id         | bigint  | PK                       |
| user_id    | bigint  | NOT NULL, FK → users(id) |
| name       | string  | NOT NULL                 |
| created_at | datetime | NOT NULL               |
| updated_at | datetime | NOT NULL               |

**Indexes**: `index_categories_on_user_id`, unique index on `(user_id, name)`
to prevent duplicate category names per user.

### Table: `transactions`

| Column           | Type    | Constraints                   |
|------------------|---------|-------------------------------|
| id               | bigint  | PK                            |
| user_id          | bigint  | NOT NULL, FK → users(id)      |
| category_id      | bigint  | NOT NULL, FK → categories(id) |
| amount           | decimal | NOT NULL, precision: 15, scale: 2 |
| transaction_type | string  | NOT NULL (`income` / `expense`) |
| transacted_on    | date    | NOT NULL                      |
| note             | text    |                               |
| created_at       | datetime | NOT NULL                     |
| updated_at       | datetime | NOT NULL                     |

**Indexes**: `index_transactions_on_user_id`,
`index_transactions_on_category_id`,
`index_transactions_on_transacted_on` (used in date-range filters),
`index_transactions_on_user_id_and_transacted_on` (composite, for dashboard
queries).

**Rules**:
- `amount` is always stored as a positive decimal. The sign semantics are
  carried by `transaction_type`.
- `transaction_type` is limited to `["income", "expense"]`.
- `transacted_on` is a `date` column; time-of-day is not tracked.

---

## 5. Models

### `User` (`app/models/user.rb`)

```ruby
# Devise handles authentication columns.
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :categories, dependent: :destroy
  has_many :transactions, dependent: :destroy
end
```

### `Category` (`app/models/category.rb`)

```ruby
class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true,
                   uniqueness: { scope: :user_id, case_sensitive: false }

  scope :for_user, ->(user) { where(user: user) }
end
```

### `Transaction` (`app/models/transaction.rb`)

> **Note**: Because `transaction` is a reserved method name in ActiveRecord,
> the Rails model is named `Transaction` but the table stays `transactions`.
> No renaming is required; Rails handles this transparently.

```ruby
class Transaction < ApplicationRecord
  TYPES = %w[income expense].freeze

  belongs_to :user
  belongs_to :category

  validates :amount, presence: true,
                     numericality: { greater_than: 0 }
  validates :transaction_type, inclusion: { in: TYPES }
  validates :transacted_on, presence: true

  scope :for_user,    ->(user)  { where(user: user) }
  scope :income,      ->        { where(transaction_type: "income") }
  scope :expense,     ->        { where(transaction_type: "expense") }
  scope :in_period,   ->(start_date, end_date) {
    where(transacted_on: start_date..end_date)
  }
  scope :by_category, ->(cat_id) { where(category_id: cat_id) }
  scope :by_type,     ->(type)   { where(transaction_type: type) }
  scope :recent,      ->         { order(transacted_on: :desc, id: :desc) }
end
```

---

## 6. Controllers

All controllers inherit from `ApplicationController`, which enforces
authentication via `before_action :authenticate_user!`.

### `ApplicationController`

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end
```

### `DashboardController` (`app/controllers/dashboard_controller.rb`)

| Action | Description |
|--------|-------------|
| `index` | Renders the statistics dashboard for the selected period |

Query logic (totals, category breakdown) is delegated to a Service Object
`DashboardStats`.

### `TransactionsController` (`app/controllers/transactions_controller.rb`)

| Action    | Description                                           |
|-----------|-------------------------------------------------------|
| `index`   | Lists transactions with optional filters; supports CSV format |
| `new`     | Displays blank transaction form                       |
| `create`  | Saves a new transaction                               |
| `edit`    | Displays edit form for an existing transaction        |
| `update`  | Saves changes to an existing transaction              |
| `destroy` | Permanently removes a transaction                     |

- Filters (date range, category, type) are applied via model scopes.
- `index` responds to `:html` and `:csv` formats for export.
- Resource loading uses `before_action :set_transaction` scoped to
  `current_user.transactions` to enforce ownership.

### `CategoriesController` (`app/controllers/categories_controller.rb`)

| Action    | Description                              |
|-----------|------------------------------------------|
| `index`   | Lists the current user's categories      |
| `new`     | Displays blank category form             |
| `create`  | Saves a new category                     |
| `edit`    | Displays edit form for a category        |
| `update`  | Saves changes to a category              |
| `destroy` | Deletes a category (blocked if it has transactions) |

---

## 7. Routes

```ruby
Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  root "devise/sessions#new"

  resource  :dashboard, only: [:show], controller: "dashboard"
  resources :transactions do
    collection do
      get :export_csv
    end
  end
  resources :categories
end
```

**Key routes**:

| Method | Path                        | Controller#Action              |
|--------|-----------------------------|--------------------------------|
| GET    | `/`                         | `devise/sessions#new`          |
| GET    | `/dashboard`                | `dashboard#show`               |
| GET    | `/transactions`             | `transactions#index`           |
| GET    | `/transactions/export_csv`  | `transactions#export_csv`      |
| GET    | `/transactions/new`         | `transactions#new`             |
| POST   | `/transactions`             | `transactions#create`          |
| GET    | `/transactions/:id/edit`    | `transactions#edit`            |
| PATCH  | `/transactions/:id`         | `transactions#update`          |
| DELETE | `/transactions/:id`         | `transactions#destroy`         |
| GET    | `/categories`               | `categories#index`             |
| GET    | `/categories/new`           | `categories#new`               |
| POST   | `/categories`               | `categories#create`            |
| GET    | `/categories/:id/edit`      | `categories#edit`              |
| PATCH  | `/categories/:id`           | `categories#update`            |
| DELETE | `/categories/:id`           | `categories#destroy`           |

---

## 8. Views

All views are ERB templates. Tailwind CSS provides styling. Shared partials
are prefixed with `_`.

### Layout

- `app/views/layouts/application.html.erb` — main layout with navigation bar
  (Dashboard, Transactions, Categories, Sign out)

### Dashboard

- `app/views/dashboard/show.html.erb` — period selector tabs (Today / This
  Week / This Month), summary cards (Total Income, Total Expenses, Net
  Balance), and category breakdown table.

### Transactions

- `app/views/transactions/index.html.erb` — filter bar (date range, category
  dropdown, type dropdown), transaction table with pagination, "Export CSV"
  button.
- `app/views/transactions/new.html.erb`
- `app/views/transactions/edit.html.erb`
- `app/views/transactions/_form.html.erb` — shared form partial (amount,
  date, type, category, note fields).

### Categories

- `app/views/categories/index.html.erb` — category list with edit/delete
  actions.
- `app/views/categories/new.html.erb`
- `app/views/categories/edit.html.erb`
- `app/views/categories/_form.html.erb` — shared form partial.

### Devise (generated)

- `app/views/devise/sessions/new.html.erb` — sign-in form
- `app/views/devise/registrations/new.html.erb` — sign-up form

---

## 9. Dashboard Logic

The dashboard displays three summary figures and a category breakdown for a
selected time period.

### Period Resolution

| Period      | Date Range                                        |
|-------------|---------------------------------------------------|
| `today`     | `Date.current..Date.current`                      |
| `this_week` | `Date.current.beginning_of_week..Date.current.end_of_week` |
| `this_month`| `Date.current.beginning_of_month..Date.current.end_of_month` |

Default period: `this_month`.

### Service Object: `DashboardStats`

Located at `app/services/dashboard_stats.rb`. Receives `user` and
`(start_date, end_date)`. Exposes:

```ruby
class DashboardStats
  def initialize(user, start_date, end_date)
    @scope = user.transactions.in_period(start_date, end_date)
  end

  # Returns BigDecimal
  def total_income
    @scope.income.sum(:amount)
  end

  def total_expense
    @scope.expense.sum(:amount)
  end

  def net_balance
    total_income - total_expense
  end

  # Returns array of { category_name:, total: }
  def category_breakdown
    @scope.expense
          .joins(:category)
          .group("categories.name")
          .sum(:amount)
  end
end
```

All aggregation is done at the SQL level (`SUM`) — no Ruby enumeration over
loaded records.

---

## 10. CSV Export

Export uses Ruby's built-in `CSV` library. The exported records respect the
same filter parameters as the transaction list view.

### Controller action (`transactions#export_csv`)

```ruby
def export_csv
  @transactions = filtered_transactions  # same scope as index
  filename = "transactions_#{params[:start_date]}_#{params[:end_date]}.csv"

  respond_to do |format|
    format.csv do
      response.headers["Content-Disposition"] =
        "attachment; filename=\"#{filename}\""
      render plain: generate_csv(@transactions)
    end
  end
end
```

### CSV columns

| Header   | Source attribute             |
|----------|------------------------------|
| Date     | `transaction.transacted_on`  |
| Type     | `transaction.transaction_type` (income / expense) |
| Amount   | `transaction.amount`         |
| Category | `transaction.category.name`  |
| Note     | `transaction.note`           |

### Streaming for large datasets

When the result set may exceed ~5,000 rows, the controller switches to
streaming:

```ruby
self.response.headers["Content-Type"]        = "text/csv"
self.response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
self.response.headers["X-Accel-Buffering"]   = "no"

self.response_body = Enumerator.new do |yielder|
  yielder << CSV.generate_line(["Date", "Type", "Amount", "Category", "Note"])
  @transactions.find_each do |txn|
    yielder << CSV.generate_line([...])
  end
end
```

---

## 11. Directory Structure

```
expense_tracker/
├── docker-compose.yml
├── Gemfile
├── config/
│   ├── database.yml
│   └── routes.rb
├── db/
│   └── migrate/
│       ├── 20260313000001_devise_create_users.rb
│       ├── 20260313000002_create_categories.rb
│       └── 20260313000003_create_transactions.rb
├── app/
│   ├── models/
│   │   ├── user.rb
│   │   ├── category.rb
│   │   └── transaction.rb
│   ├── services/
│   │   └── dashboard_stats.rb
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── transactions_controller.rb
│   │   └── categories_controller.rb
│   └── views/
│       ├── layouts/
│       │   └── application.html.erb
│       ├── dashboard/
│       │   └── show.html.erb
│       ├── transactions/
│       │   ├── index.html.erb
│       │   ├── new.html.erb
│       │   ├── edit.html.erb
│       │   └── _form.html.erb
│       ├── categories/
│       │   ├── index.html.erb
│       │   ├── new.html.erb
│       │   ├── edit.html.erb
│       │   └── _form.html.erb
│       └── devise/
│           ├── sessions/
│           │   └── new.html.erb
│           └── registrations/
│               └── new.html.erb
└── spec/
    ├── models/
    │   ├── user_spec.rb
    │   ├── category_spec.rb
    │   └── transaction_spec.rb
    ├── controllers/
    │   ├── transactions_controller_spec.rb
    │   └── categories_controller_spec.rb
    └── system/
        ├── user_authentication_spec.rb
        ├── transactions_spec.rb
        └── dashboard_spec.rb
```

---

## 12. Primary Files to Be Created by AI

| File | Purpose |
|------|---------|
| `docker-compose.yml` | PostgreSQL container definition |
| `Gemfile` | Gem dependencies (devise, rubocop-rails, bullet, rspec-rails, etc.) |
| `config/database.yml` | Database connection configuration |
| `config/routes.rb` | Route definitions |
| `db/migrate/..._devise_create_users.rb` | Users table migration |
| `db/migrate/..._create_categories.rb` | Categories table with FK and indexes |
| `db/migrate/..._create_transactions.rb` | Transactions table with FK and indexes |
| `app/models/user.rb` | User model with Devise |
| `app/models/category.rb` | Category model with validations |
| `app/models/transaction.rb` | Transaction model with scopes |
| `app/services/dashboard_stats.rb` | Dashboard aggregation service |
| `app/controllers/application_controller.rb` | Base controller with auth |
| `app/controllers/dashboard_controller.rb` | Dashboard action |
| `app/controllers/transactions_controller.rb` | Full CRUD + CSV export |
| `app/controllers/categories_controller.rb` | Full CRUD |
| `app/views/layouts/application.html.erb` | Main layout with nav |
| `app/views/dashboard/show.html.erb` | Dashboard page |
| `app/views/transactions/index.html.erb` | Transaction list with filters |
| `app/views/transactions/new.html.erb` | New transaction page |
| `app/views/transactions/edit.html.erb` | Edit transaction page |
| `app/views/transactions/_form.html.erb` | Transaction form partial |
| `app/views/categories/index.html.erb` | Category list |
| `app/views/categories/new.html.erb` | New category page |
| `app/views/categories/edit.html.erb` | Edit category page |
| `app/views/categories/_form.html.erb` | Category form partial |
| `spec/models/transaction_spec.rb` | Model validations and scopes |
| `spec/models/category_spec.rb` | Model validations |
| `spec/controllers/transactions_controller_spec.rb` | Auth and ownership |
| `spec/system/transactions_spec.rb` | End-to-end transaction flow |

---

## 13. Implementation Steps

Follow these steps in order. Each step produces a testable checkpoint.

### Step 1 — Create Rails Project

```bash
rails new expense_tracker \
  --database=postgresql \
  --skip-javascript \
  --css=tailwind
```

Add gems to `Gemfile`:

```ruby
gem "devise"

group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers"
end

group :development do
  gem "bullet"
  gem "rubocop-rails", require: false
  gem "rubocop-rspec",  require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
```

### Step 2 — Create `docker-compose.yml`

Create the file as shown in Section 2.

### Step 3 — Start the Database Container

```bash
docker compose up -d db
```

Verify with:

```bash
docker compose ps
```

### Step 4 — Configure `config/database.yml`

Update as shown in Section 3. Verify connection:

```bash
bin/rails db:create
```

### Step 5 — Install Devise and Generate User Model

```bash
bin/rails generate devise:install
bin/rails generate devise User
```

Review and adjust the generated migration to add `null: false` constraints
where applicable.

### Step 6 — Create Category Migration and Model

```bash
bin/rails generate model Category user:references name:string:index
```

Edit migration to add:
- `null: false` on all required columns
- `add_index :categories, [:user_id, :name], unique: true`
- `add_foreign_key :categories, :users`

Create `app/models/category.rb` as shown in Section 5.

### Step 7 — Create Transaction Migration and Model

```bash
bin/rails generate model Transaction \
  user:references \
  category:references \
  amount:decimal{15,2} \
  transaction_type:string \
  transacted_on:date \
  note:text
```

Edit migration to add:
- `null: false` on all required columns
- Indexes on `user_id`, `category_id`, `transacted_on`,
  composite `(user_id, transacted_on)`
- `add_foreign_key :transactions, :users`
- `add_foreign_key :transactions, :categories`

Create `app/models/transaction.rb` as shown in Section 5.

### Step 8 — Run Migrations

```bash
bin/rails db:migrate
```

### Step 9 — Create Service Object

Create `app/services/dashboard_stats.rb` as shown in Section 9.

### Step 10 — Implement Controllers

Create in order:
1. `app/controllers/application_controller.rb`
2. `app/controllers/dashboard_controller.rb`
3. `app/controllers/categories_controller.rb`
4. `app/controllers/transactions_controller.rb`

Ensure every action scopes queries to `current_user` and every `set_*`
`before_action` uses `current_user.model.find(params[:id])` to prevent
cross-user access.

Enable N+1 detection in `config/environments/development.rb`:

```ruby
config.after_initialize do
  Bullet.enable        = true
  Bullet.rails_logger  = true
  Bullet.raise         = true   # raise error on N+1 in development
end
```

### Step 11 — Define Routes

Update `config/routes.rb` as shown in Section 7.

### Step 12 — Build Views

Create ERB templates in the order below (each one can be smoke-tested in the
browser as it is created):

1. `app/views/layouts/application.html.erb`
2. Devise views (`bin/rails generate devise:views` then trim to sessions and
   registrations)
3. `app/views/dashboard/show.html.erb`
4. `app/views/transactions/` — index, new, edit, _form
5. `app/views/categories/` — index, new, edit, _form

Apply Tailwind utility classes for basic, readable styling.

### Step 13 — Implement Dashboard

Wire `DashboardController#show` to `DashboardStats`. Parse the `period`
query parameter (`today` / `this_week` / `this_month`) to compute
`start_date` and `end_date`. Pass stats to the view.

### Step 14 — Add CSV Export

Add `transactions#export_csv` route and action. Reuse the same filter scope
as `index`. Generate CSV using Ruby's built-in library with the headers
defined in Section 10.

### Step 15 — Write Tests

1. Model specs: validations, scopes, and associations (RSpec + Shoulda)
2. Controller specs: authentication redirect, ownership enforcement
3. System specs (Capybara): create transaction → verify in list, view
   dashboard → verify totals, export CSV → verify file content

### Step 16 — Lint and Review

```bash
bundle exec rubocop --autocorrect
```

Resolve all remaining offences. Review Bullet output in development logs for
any N+1 warnings.

---

## Constitution Compliance Summary

| Principle | How Addressed |
|-----------|---------------|
| I — Rails MVC, server-side ERB | No SPA; all views are ERB; Stimulus for minor interactivity |
| II — Data model integrity | Migrations include `null: false`, FK constraints, decimal `amount` |
| III — Thin controllers | Business logic in `DashboardStats` service; scopes on models |
| IV — Transaction & Category rules | `restrict_with_error` on category delete; positive `amount`; `date` column |
| V — Dashboard accuracy | All totals via SQL `SUM`; queries scoped to `current_user` |
| VI — CSV export | Built-in `CSV` library; respects filters; filename includes date range |
| VII — N+1 prevention | `includes(:category)` on index queries; Bullet gem raises in development |
| VIII — Code standards | RuboCop enforced; snake_case files; partials for repeated fragments |
