# dev-experience-coc-2026-q2

A Rails application for basic UML analysis (Actors, Use Cases, Sequences) with a
Template/App hierarchy.

## What It Does

Provides a web UI for browsing and managing first-level UML specs. A **Template**
defines platform-level actors, use cases, and sequences. An **App** applies a
template to a specific domain, scoping the specs to one actor's perspective.

## Example

- **Template:** `rails-coc-2026-q2` defines RCOC_ACTORS, RCOC_USE_CASES, RCOC_SEQUENCES
- **App:** `b-and-h` applies that template with three sub-apps:
  - `rcoc-human-customer` — the Customer's view
  - `rcoc-human-agent` — the Human_Agent's view
  - `rcoc-ai-agent` — the AI_Agent's view

## Stack

- Ruby 3.4 / Rails 8.1
- SQLite
- ViewComponent (view_component gem) for encapsulated, testable UI components
- Lookbook for component preview and documentation
- Tailwind CSS for styling
- Stimulus for JS interactions (Hotwire stack)

## Getting Started

```bash
cd vendor/dev-experience-coc-2026-q2
bundle install
bin/rails db:setup
bin/rails server
```

## See Also

- [PLAN.md](PLAN.md) — Domain models, relationships, routes, and implementation order
