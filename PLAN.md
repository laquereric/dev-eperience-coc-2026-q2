# dev-experience-coc-2026-q2 PLAN

A Rails **engine** for basic UML analysis: Actors, Use Cases, and Sequences.
Supports a Template/App hierarchy where a Template defines platform-level UML
and an App applies that template to a specific domain.

## Architecture: Engine + App Template

`dev-experience-coc-2026-q2` is a **mountable Rails engine**, not a standalone app.
A host application is created with `app_template.rb`:

```bash
rails new my_app --database=sqlite3 --css=tailwind \
  --template=https://github.com/laquereric/dev-experience-coc-2026-q2/app_template.rb
```

The template:
1. Adds the engine gem and mounts it at `/dx`
2. Sets `/dx` as the **only top-level route** (root redirects to `/dx`)
3. Installs ViewComponent + view_component-contrib + Lookbook + dry-initializer
4. Configures sidecar component pattern at `app/frontend/components/`
5. Creates a custom `view_component` generator for the host app

### Engine Structure

```
dev-experience-coc-2026-q2/
├── app_template.rb              # builds the host Rails app
├── lib/
│   └── dev_experience/
│       ├── engine.rb            # isolate_namespace DevExperience
│       └── version.rb
├── app/
│   ├── models/dev_experience/   # Template, App, Actor, UseCase, Sequence, Step
│   ├── controllers/dev_experience/
│   ├── views/dev_experience/
│   └── components/dev_experience/  # ViewComponents (sidecar pattern)
├── config/
│   └── routes.rb                # engine-internal routes
├── db/
│   └── migrate/                 # engine migrations (install to host via rake)
└── spec/
```

### Host App Structure (after template runs)

```
my_app/
├── Gemfile                      # includes dev_experience engine
├── config/routes.rb             # mount DevExperience::Engine, at: "/dx"
├── app/frontend/components/     # host-level ViewComponents (if any)
└── lib/generators/view_component/  # custom generator from template
```

## Core Concepts

### Template

A reusable set of first-level UML specs (ACTORS.md, USE_CASES.md, SEQUENCES.md).
Example: `rails-coc-2026-q2` defines RCOC_ACTORS, RCOC_USE_CASES, RCOC_SEQUENCES.

### App

An application of a Template to a specific domain. Inherits the Template's actors
and use cases, then narrows them to a specific perspective or context.
Example: `b-and-h` applies `rails-coc-2026-q2` with three apps (rcoc-human-user,
rcoc-human-agent, rcoc-ai-agent), each scoping the RCOC specs to one actor's view.

## Domain Models

### Template

| Field       | Type   | Description                          |
|-------------|--------|--------------------------------------|
| name        | string | e.g. "rails-coc-2026-q2"            |
| description | text   | Purpose of this template             |
| repo_url    | string | Git repo where specs live            |

### App

| Field       | Type       | Description                          |
|-------------|------------|--------------------------------------|
| name        | string     | e.g. "b-and-h"                       |
| template    | belongs_to | The Template this App applies        |
| repo_url    | string     | Git repo for the application         |

### Actor

| Field       | Type       | Description                          |
|-------------|------------|--------------------------------------|
| name        | string     | e.g. "User", "AI_Agent"             |
| description | text       | Role description                     |
| owner       | polymorphic| Belongs to Template or App           |

### UseCase

| Field       | Type       | Description                          |
|-------------|------------|--------------------------------------|
| identifier  | string     | e.g. "UC-1"                          |
| name        | string     | e.g. "Authenticate"                  |
| description | text       | What the use case does               |
| owner       | polymorphic| Belongs to Template or App           |
| implements  | belongs_to | Optional: the Template UseCase this implements |

### UseCaseActor (join)

| Field       | Type       | Description                          |
|-------------|------------|--------------------------------------|
| use_case    | belongs_to | The UseCase                          |
| actor       | belongs_to | The Actor involved                   |

### Sequence

| Field       | Type       | Description                          |
|-------------|------------|--------------------------------------|
| name        | string     | e.g. "Session Establishment"         |
| owner       | polymorphic| Belongs to Template or App           |

### Step

| Field       | Type       | Description                          |
|-------------|------------|--------------------------------------|
| sequence    | belongs_to | Parent Sequence                      |
| position    | integer    | Order within the sequence            |
| from_actor  | belongs_to | Actor initiating the step            |
| to_actor    | belongs_to | Actor receiving the step             |
| action      | string     | e.g. "logs_into", "offers_help"      |

## Relationships

```
Template -has_many-> Actors
Template -has_many-> UseCases
Template -has_many-> Sequences
Template -has_many-> Apps

App -belongs_to-> Template
App -has_many-> Actors
App -has_many-> UseCases (each optionally implements a Template UseCase)
App -has_many-> Sequences

UseCase -has_many-> UseCaseActors -belongs_to-> Actor
UseCase -belongs_to (optional)-> UseCase (implements)

Sequence -has_many-> Steps (ordered by position)
Step -belongs_to-> from_actor (Actor)
Step -belongs_to-> to_actor (Actor)
```

## View Layer: ViewComponent

The UI is built with the `view_component` gem — encapsulated, testable, reusable
Ruby objects that render HTML. Each UML concept gets its own component.

### Components

| Component                | Renders                                      |
|--------------------------|----------------------------------------------|
| `ActorCardComponent`     | Single actor: name, description, owner badge |
| `ActorListComponent`     | Grid/list of ActorCardComponents             |
| `UseCaseCardComponent`   | Single use case: identifier, name, actors, implements link |
| `UseCaseListComponent`   | Grid/list of UseCaseCardComponents           |
| `SequenceDiagramComponent` | A sequence as `Actor -action-> Actor` steps |
| `SequenceListComponent`  | List of SequenceDiagramComponents            |
| `TemplateHeaderComponent`| Template name, description, repo link        |
| `AppHeaderComponent`     | App name, template link, repo link           |

### Supporting Tools

- **Lookbook** — Preview and document each component in isolation (`/lookbook`)
- **Tailwind CSS** — Utility-first styling for components
- **Stimulus** — JS controllers for expand/collapse, filtering, tab switching

### Component Pattern (sidecar, dry-initializer)

```ruby
# app/components/dev_experience/actor_card/component.rb
module DevExperience
  class ActorCard::Component < ApplicationViewComponent
    option :actor
  end
end
```

```erb
<%# app/components/dev_experience/actor_card/component.html.erb %>
<div class="border rounded p-4">
  <h3><%= actor.name %></h3>
  <p><%= actor.description %></p>
  <span class="text-sm text-gray-500"><%= actor.owner_type %>: <%= actor.owner.name %></span>
</div>
```

## Routes

Host app mounts the engine at `/dx`. All engine routes are prefixed:

```
# Host routes.rb
mount DevExperience::Engine, at: "/dx"
root to: redirect("/dx")

# Engine-internal routes (config/routes.rb inside engine)
/dx/templates
/dx/templates/:id
/dx/templates/:id/actors
/dx/templates/:id/use_cases
/dx/templates/:id/sequences

/dx/apps
/dx/apps/:id
/dx/apps/:id/actors
/dx/apps/:id/use_cases
/dx/apps/:id/sequences

/lookbook  (development only — component previews, host-level)
```

## Markdown Import

The app should parse existing spec files (ACTORS.md, USE_CASES.md, SEQUENCES.md)
to seed Templates and Apps. The parser reads:

- `## N. Name` headings from ACTORS.md -> Actor records
- `## UC-N: Name` headings + `**Actor:**` / `**Implements:**` lines from USE_CASES.md -> UseCase + UseCaseActor records
- Fenced code blocks with `Actor -action-> Actor` lines from SEQUENCES.md -> Sequence + Step records

## Hindsight Integration

The engine depends on the `hindsight` gem (vendor/hindsight) to sync UML specs
into Hindsight memory banks for AI-powered recall and reflection.

### Bank Strategy

Each Template and App gets its own Hindsight memory bank:

| Owner                  | Bank ID                             |
|------------------------|-------------------------------------|
| rails-coc-2026-q2     | `dx:template:rails-coc-2026-q2`    |
| rcoc-human-user app    | `dx:app:rcoc-human-user`           |
| rcoc-human-agent app   | `dx:app:rcoc-human-agent`          |
| rcoc-ai-agent app      | `dx:app:rcoc-ai-agent`             |

Banks are auto-created on first sync with a `retain_mission` tuned for UML extraction.

### Tagging

Every retained item is tagged for filtering:

- `template:<name>` or `app:<name>` — owner identity
- `spec_type:actors|use_cases|sequences` — spec file type

### `document_id` for Idempotent Sync

Each spec file is retained with `document_id: "<dir_name>:<basename>"`,
so re-running sync upserts (replaces) rather than duplicates.

### Rake Tasks

```bash
# Sync ALL templates (vendor/*) and apps (apps/*) that have spec files
bin/rails hindsight:sync

# Sync a single template
bin/rails "hindsight:sync_template[vendor/rails-coc-2026-q2,rails-coc-2026-q2]"

# Sync a single app
bin/rails "hindsight:sync_app[apps/rcoc-human-user,rcoc-human-user,rails-coc-2026-q2]"
```

### UmlSync Module

`DevExperience::UmlSync` provides the sync logic:

- `sync_template(path:, name:)` — reads spec files from a template dir, retains to bank
- `sync_app(path:, name:, template_name:)` — same for an app dir, with template tag
- Auto-creates banks with appropriate `retain_mission`
- Uses `document_id` for idempotent upserts

## Implementation Order

### Phase 1: Engine scaffold
1. Scaffold the engine: `rails plugin new dev_experience --mountable --database=sqlite3`
2. Add engine gems: `view_component`, `view_component-contrib`, `dry-initializer`, `hindsight`
3. Set up `isolate_namespace DevExperience` in `engine.rb`

### Phase 2: Domain models (inside engine)
4. Generate models: Template, App, Actor, UseCase, UseCaseActor, Sequence, Step
5. Add install generator to copy migrations to host app

### Phase 3: View layer (inside engine)
6. Build ViewComponents (sidecar pattern): ActorCard, UseCaseCard, SequenceDiagram, and list wrappers
7. Add Lookbook previews for each component
8. Wire engine controllers and routes to render components

### Phase 4: Import + Hindsight sync
9. Build the Markdown parser (`lib/dev_experience/uml_import.rb`) for DB seeding
10. Implement `DevExperience::UmlSync` and `hindsight:sync` rake task (**done**)
11. Seed from rails-coc-2026-q2 RCOC specs (Template) and b-and-h app specs (Apps)
12. Run `bin/rails hindsight:sync` to populate memory banks

### Phase 5: Host app
13. Test `app_template.rb` end-to-end:
    ```bash
    rails new test_app --database=sqlite3 --css=tailwind \
      --template=vendor/dev-experience-coc-2026-q2/app_template.rb
    ```
14. Verify: single route at `/dx`, ViewComponent generator works, Lookbook loads
15. Verify: `bin/rails hindsight:sync` populates banks, `Hindsight.client.recall` returns specs
