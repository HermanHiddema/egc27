# AI Coding Agent Instructions for egc27

## Project Overview
**egc27** is a Rails 8.1 full-stack web application using modern Rails conventions. It features Hotwire (Turbo + Stimulus), Devise authentication, SQLite database, and Docker deployment via Kamal.

## Architecture

### Tech Stack
- **Framework**: Rails 8.1 with `propshaft` asset pipeline
- **Database**: SQLite with `solid_queue`, `solid_cache`, `solid_cable` for modern Rails defaults
- **Frontend**: Hotwire (Turbo + Stimulus via importmap-rails), no Node build step
- **Authentication**: Devise with database-backed user model
- **Deployment**: Docker + Kamal orchestration
- **Testing**: Minitest with parallel execution and fixtures

### Key Architecture Points
- **Routing**: Only authenticated users see the home page (see `config/routes.rb` - uses `authenticated :user` block)
- **Controllers**: All controllers inherit from `ApplicationController`, which enforces `authenticate_user!` before action for non-Devise routes
- **JavaScript**: Minimal - use Stimulus controllers in `app/javascript/controllers/` for interactivity; Turbo handles SPA-like navigation
- **Styling**: Tailwind CSS via `tailwindcss-rails` gem + custom CSS variables in `app/assets/stylesheets/`; see `DESIGN_SYSTEM.md` for brand colors, typography, and component classes

## Code Style & Conventions

### Ruby/Rails
- **Linting**: RuboCop Rails Omakase (`rubocop-rails-omakase`) - follow its rules strictly
- **Run locally**: `bin/rubocop` to check; use `--fix-all` for automatic fixes
- **Structure**: Standard Rails conventions - no custom patterns detected yet

### Directory Conventions
```
app/controllers/     → HTTP request handlers, enforce auth pattern
app/models/          → ActiveRecord models, Devise models here
app/views/           → ERB templates, organized by controller
app/javascript/      → Stimulus controllers and shared JS
app/assets/stylesheets/ → CSS stylesheets (custom vars) + app/assets/builds/tailwind.css (generated)
config/routes.rb     → Single auth gateway - critical file
```

## Development Workflows

### Setup & Running
- **First time**: `bin/setup` - Bundles gems, prepares database, clears logs
- **Daily development**: `bin/dev` - Starts Rails server on port 3000
- **Database**: Use `bin/rails db:migrate` for schema changes, `db:seed` for data

### Testing
- **Unit/Controller tests**: `bin/rails test` (runs in parallel)
- **System/Integration tests**: `bin/rails test:system` (uses Selenium by default)
- **Full CI locally**: `bin/ci` - Runs entire pipeline (style, security, unit, system tests)
- **Test data**: Use fixtures in `test/fixtures/*.yml` for managed test data

### Quality Checks (in CI order)
1. `bin/rubocop` - Ruby code style
2. `bin/bundler-audit` - Gem vulnerability check
3. `bin/importmap audit` - JavaScript dependency audit
4. `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` - Security analysis
5. `bin/rails test` + `bin/rails test:system` - Test suite
6. `env RAILS_ENV=test bin/rails db:seed:replant` - Verify seed data

All must pass before deploy.

## Critical Integration Points

### Authentication Flow
1. All non-Devise routes require `authenticate_user!` (set in `ApplicationController`)
2. Devise routes (login/signup) are public, routed via `devise_for :users`
3. Root path logic: authenticated users → `HomeController#index`, unauthenticated → Devise sign-in page

### Browser Support
- Only modern browsers (WebP, web push, CSS nesting, CSS :has support) due to `allow_browser versions: :modern` in ApplicationController
- Don't worry about IE11 compatibility

### Database
- SQLite in development/test; consider adapting for production PostgreSQL if needed
- All DB state lives in `db/schema.rb` and migrations in `db/migrate/`
- Jobs/cache use solid_* adapters (database-backed, no Redis dependency)

## When Implementing Features

- **New model**: Add to `app/models/`, use `bin/rails generate model YourModel` 
- **New controller**: Use `bin/rails generate controller YourController` - authentication is automatic
- **New view**: ERB templates in `app/views/controller_name/action_name.html.erb`
- **JavaScript interactivity**: Add Stimulus controller in `app/javascript/controllers/your_controller.js`
- **Styling**: Add CSS to `app/assets/stylesheets/` (custom CSS variables) or use Tailwind utility classes; run `bin/rails tailwindcss:build` after changing Tailwind config
- **Tests**: Add to `test/models/`, `test/controllers/`, `test/system/` with naming convention `test_*.rb`

## Special Files to Know
- `config/routes.rb` - Guards all routes with auth (study carefully when routing)
- `config/ci.rb` - Defines CI pipeline; update here if adding checks
- `DESIGN_SYSTEM.md` - Brand colors, typography, component classes (Tailwind + CSS vars)
- `Gemfile` - All dependencies; commit `Gemfile.lock` only after changes
- `.ruby-version` - Currently Ruby 3.4.5; change if updating Ruby
- `Dockerfile` - Production image build; no dev-only gems in bundle

## Quick Diagnostics
- **Server won't start**: Check `bin/rails db:prepare` hasn't crashed
- **Tests fail mysteriously**: Run `bin/ci` locally to match CI environment exactly
- **CSS not updating**: Clear `tmp/` and browser cache; run `bin/rails tailwindcss:build` to regenerate Tailwind CSS
- **Gem conflicts**: Run `bundle update` carefully; always check Gemfile.lock diffs
