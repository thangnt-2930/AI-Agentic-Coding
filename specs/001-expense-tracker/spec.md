# Feature Specification: Expense Tracker

**Feature Branch**: `001-expense-tracker`
**Created**: 2026-03-13
**Status**: Draft

## User Scenarios & Testing *(mandatory)*

### User Story 1 — User Account Management (Priority: P1)

A new visitor can sign up for an account using their email and password.
An existing user can sign in and sign out securely.
All personal financial data is visible only to the authenticated owner.

**Why this priority**: Every other feature is gated behind authentication.
Without an account system there is no MVP to demonstrate.

**Independent Test**: Register a new account, sign in, and verify that the
home page is accessible while an unauthenticated request to any protected page
is redirected to the sign-in screen.

**Acceptance Scenarios**:

1. **Given** a visitor on the sign-up page, **When** they submit a valid email
   and password, **Then** an account is created and they are redirected to the
   dashboard as a signed-in user.
2. **Given** a visitor submits a sign-up form with an already-registered email,
   **When** the form is submitted, **Then** an error message is shown and no
   duplicate account is created.
3. **Given** a registered user on the sign-in page, **When** they submit correct
   credentials, **Then** they are signed in and redirected to the dashboard.
4. **Given** a registered user submits wrong credentials, **When** the form is
   submitted, **Then** an error message is shown and access is denied.
5. **Given** a signed-in user, **When** they click "Sign out", **Then** their
   session is ended and they are redirected to the sign-in page.
6. **Given** an unauthenticated visitor, **When** they navigate to any
   protected URL (transactions, dashboard, etc.), **Then** they are redirected
   to the sign-in page.

---

### User Story 2 — Manage Categories (Priority: P2)

A signed-in user can create personal spending/income categories (e.g.
"Groceries", "Salary", "Rent") to organise their transactions.
Each category belongs exclusively to its creator.

**Why this priority**: Transactions must be assigned a category, so categories
must exist before any transaction can be created. This is the foundational
data needed by the core feature.

**Independent Test**: Create two categories, verify they appear in the category
list, rename one, and confirm that the renamed label is reflected immediately.

**Acceptance Scenarios**:

1. **Given** a signed-in user on the new category page, **When** they submit a
   non-empty name, **Then** the category is saved and appears in their category
   list.
2. **Given** a signed-in user submits an empty category name, **When** the form
   is submitted, **Then** a validation error is shown and nothing is saved.
3. **Given** a signed-in user, **When** they view the category list, **Then**
   only their own categories are displayed (not those of other users).
4. **Given** an existing category with no associated transactions, **When** the
   user deletes it, **Then** the category is removed from the list.
5. **Given** an existing category that has at least one associated transaction,
   **When** the user attempts to delete it, **Then** deletion is blocked and an
   explanatory message is shown.
6. **Given** an existing category, **When** the user edits its name and saves,
   **Then** the updated name is shown everywhere that category appears.

---

### User Story 3 — Record a Transaction (Priority: P3)

A signed-in user can record an income or expense transaction by specifying
the amount, date, type (income / expense), category, and an optional note.
Recorded transactions are private to the user who created them.

**Why this priority**: Recording transactions is the primary action of the
application. All reporting and export features depend on having transaction
data.

**Independent Test**: Record one income transaction and one expense transaction,
then verify both appear in the transaction list with correct labels and amounts.

**Acceptance Scenarios**:

1. **Given** a signed-in user on the new transaction page, **When** they submit
   a valid amount, date, type, and category, **Then** the transaction is saved
   and they are returned to the transaction list with a success notice.
2. **Given** a signed-in user submits the form with a missing or zero amount,
   **When** the form is submitted, **Then** a validation error is shown and
   nothing is saved.
3. **Given** a signed-in user submits the form with no date selected, **When**
   the form is submitted, **Then** a validation error is shown.
4. **Given** a signed-in user submits the form with no category selected,
   **When** the form is submitted, **Then** a validation error is shown.
5. **Given** an existing transaction owned by the user, **When** they edit it
   and save, **Then** the updated values are reflected in the transaction list.
6. **Given** an existing transaction owned by the user, **When** they delete it,
   **Then** it is permanently removed from the list.
7. **Given** a signed-in user, **When** they attempt to access or modify a
   transaction that belongs to a different user, **Then** they receive a "not
   found" or "forbidden" response.

---

### User Story 4 — View & Filter Transaction List (Priority: P4)

A signed-in user can view all of their transactions in a paginated list,
and narrow the list by date range, category, or transaction type.

**Why this priority**: Browsing and searching transactions is the primary
read-side of the app. A list with filters is more useful than a raw dump and
is a prerequisite for the export feature.

**Independent Test**: Record transactions across two different months and two
different categories, then apply each filter independently and confirm the
list updates to show only matching records.

**Acceptance Scenarios**:

1. **Given** a signed-in user with existing transactions, **When** they visit
   the transaction list, **Then** all their transactions are shown in
   reverse-chronological order.
2. **Given** a signed-in user applies a date-range filter (start date and end
   date), **When** the filter is submitted, **Then** only transactions whose
   date falls within that range are displayed.
3. **Given** a signed-in user selects a specific category from the filter,
   **When** the filter is submitted, **Then** only transactions in that category
   are displayed.
4. **Given** a signed-in user selects "Income" or "Expense" from the type
   filter, **When** the filter is submitted, **Then** only transactions of that
   type are displayed.
5. **Given** multiple filters are active simultaneously, **When** the list is
   displayed, **Then** only transactions matching all active filters are shown.
6. **Given** a signed-in user with no transactions matching the current filter,
   **When** the filter is applied, **Then** an empty-state message is shown
   instead of an empty table.
7. **Given** a signed-in user, **When** they view the list, **Then** no
   transactions belonging to other users are ever visible.

---

### User Story 5 — Dashboard & Statistics (Priority: P5)

A signed-in user can view a summary dashboard showing total income, total
expenses, and net balance for a selected period (current month by default),
as well as a breakdown of spending by category.

**Why this priority**: The dashboard gives the app its core reporting value.
It is non-blocking because it depends only on existing transaction data.

**Independent Test**: Record a mix of income and expense transactions across
two categories in the current month, then open the dashboard and verify the
totals and category breakdown match the recorded data.

**Acceptance Scenarios**:

1. **Given** a signed-in user with transactions in the current month, **When**
   they open the dashboard, **Then** the total income, total expenses, and net
   balance (income − expenses) for the current month are displayed correctly.
2. **Given** a signed-in user selects "This Week" as the period, **When** the
   dashboard refreshes, **Then** the totals reflect only transactions within
   the current calendar week.
3. **Given** a signed-in user selects "Today" as the period, **When** the
   dashboard refreshes, **Then** the totals reflect only today's transactions.
4. **Given** a signed-in user with transactions in multiple categories, **When**
   they view the dashboard, **Then** a category breakdown shows each category's
   share of total expense for the selected period.
5. **Given** a signed-in user with no transactions in the selected period,
   **When** they view the dashboard, **Then** all totals display as zero and
   no category breakdown rows are shown.
6. **Given** a signed-in user, **When** they view the dashboard, **Then**
   figures represent only their own transactions.

---

### User Story 6 — Export Transactions to CSV (Priority: P6)

A signed-in user can download their transaction list as a CSV file.
The exported data respects any active filters (date range, category, type).

**Why this priority**: Export is a convenience feature that adds portability.
It depends on the filter mechanism from User Story 4 but does not block any
other story.

**Independent Test**: Apply a date-range filter, click "Export CSV", open the
downloaded file, and verify it contains exactly the rows visible in the
filtered list with readable column headers.

**Acceptance Scenarios**:

1. **Given** a signed-in user on the transaction list with no filters active,
   **When** they click "Export CSV", **Then** a CSV file is downloaded
   containing all of their transactions.
2. **Given** a signed-in user with active filters (date range, category, or
   type), **When** they click "Export CSV", **Then** the downloaded CSV
   contains only transactions matching those filters.
3. **Given** the downloaded CSV, **When** opened in a spreadsheet tool, **Then**
   the first row contains human-readable column headers (e.g., "Date", "Type",
   "Amount", "Category", "Note").
4. **Given** a signed-in user with no transactions matching the current filter,
   **When** they click "Export CSV", **Then** a CSV file is downloaded
   containing only the header row and no data rows.
5. **Given** the downloaded CSV, **When** inspected, **Then** it contains no
   data belonging to any other user.

---

### Edge Cases

- What happens when a user records a transaction on the last day of a month and
  then views the "This Month" dashboard the next day? (Transaction should appear
  in the previous month's view.)
- How does the system handle a category name that is identical to an existing
  category owned by the same user? (Should be blocked with a validation error.)
- What happens if a user submits the transaction form twice in quick succession?
  (Only one transaction should be saved — prevent duplicate submissions.)
- How does the app behave when the transaction amount contains non-numeric
  characters? (Validation error; nothing saved.)
- What happens when the date-range filter has a start date after the end date?
  (Validation error or empty result with an explanatory message.)
- What happens when a user has zero transactions and exports CSV? (Header-only
  file is returned, not an error.)

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST require authentication before accessing any
  transaction, category, or dashboard page.
- **FR-002**: The system MUST allow a user to register with a unique email
  address and a password.
- **FR-003**: The system MUST allow a user to create, read, update, and delete
  their own categories.
- **FR-004**: The system MUST prevent deletion of a category that has one or
  more associated transactions.
- **FR-005**: The system MUST allow a user to create, read, update, and delete
  their own transactions.
- **FR-006**: Each transaction MUST have: amount (positive number), date,
  type (income or expense), and category.
- **FR-007**: Each transaction MAY have an optional free-text note.
- **FR-008**: The transaction list MUST be filterable by date range, category,
  and transaction type; filters can be combined.
- **FR-009**: The dashboard MUST display total income, total expenses, and net
  balance for the selected period (today / this week / this month).
- **FR-010**: The dashboard MUST display a category-level expense breakdown for
  the selected period.
- **FR-011**: The system MUST allow the user to export transactions to a CSV
  file that respects any active list filters.
- **FR-012**: The system MUST ensure that a user can never read or modify
  another user's transactions or categories.

### Key Entities

- **User**: The account holder. Has many Transactions and many Categories.
  Identified by a unique email address.
- **Category**: A label for grouping transactions (e.g., "Groceries", "Salary").
  Belongs to one User. Cannot be deleted while it has associated Transactions.
- **Transaction**: A single financial event. Belongs to one User and one
  Category. Carries: amount, date, type (income / expense), and optional note.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete registration and record their first
  transaction within 3 minutes of landing on the app for the first time.
- **SC-002**: The transaction list correctly reflects the applied filters — zero
  out-of-range records appear in a filtered result.
- **SC-003**: Dashboard totals match the arithmetic sum of the underlying
  transactions for any selected period — verified by manual spot-check during
  review.
- **SC-004**: A CSV export of 100 transactions downloads in under 3 seconds on
  a standard connection.
- **SC-005**: No page exposes any data belonging to a user other than the one
  currently signed in — verified by attempting cross-user access in review.
- **SC-006**: All six user stories can be demonstrated end-to-end in a single
  screen-share session without encountering an unhandled error.
