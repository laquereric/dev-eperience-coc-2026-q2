# DX Mirror: Reverse-Engineering Capability

## Context

Every application route (like `/products/2`) gets a DX mirror (`/dx/mirror/products/2`) that looks visually identical. The behavior is different: right-click any component and a modal dialog shows the Model, View, Controller, and Agentic source material that created that element. This bridges the gap between "what does the user see" and "what code/AI made it."

## Where Does This Live?

### The Vendor Ecosystem

```
vendor/
  context-record/              # Library — immutable JSON-LD message envelope
  cognition-client-api/        # Library — callback API (Rails <- cognition)
  cognition-provider-api/      # Library — outbound API (Rails -> cognition)
  cognition-coc-2026-q2/       # Library — intent routing rules engine
  gguf-container/              # Library — local LLM inference client
  ruby-llm-eval/               # Library — behavioral eval framework
  hindsight/                   # Library — biomimetic memory API client
  swift-view/                  # Library — ViewComponent + Swift WASM bridge
  swift-view-rails/            # Engine — Rails glue for swift-view
  engine-design-system/        # Engine — shared layout, tokens, components (3-layer)
  dev-experience-coc-2026-q2/  # Engine — UML specs, HindSight sync, /dx routes
  rails-coc-2026-q2/           # Engine — orchestrator (3-layer, planned)
  vv-deploy/                   # Engine — deployment orchestration (3-layer)
```

### Decision: Extend `dev-experience-coc-2026-q2`

DX Mirror belongs in the dev-experience engine, not a new gem. Reasons:

1. **Already owns `/dx`** — the mirror lives at `/dx/mirror/*`, which is already this engine's namespace
2. **Already has HindSight integration** — `UmlSync` syncs UML specs to memory banks; the Agentic tab is a natural extension
3. **Already uses ViewComponents** — the modal and introspection panels follow the same sidecar + dry-initializer pattern
4. **Same audience** — developers who browse UML specs at `/dx/templates` are the same people who want to right-click a product card and see its source
5. **Avoids a new gem** — a standalone `dx-mirror` gem would depend on dev-experience for HindSight sync, engine-design-system for layout, and hindsight for recall. That's 3 dependencies for what is fundamentally a new module in an existing gem.

The alternative — putting it in `engine-design-system` — was rejected because the design system is a shared foundation layer. Introspection is a dev-experience concern, not a presentation concern. The design system shouldn't know about HindSight, controllers, or models.

### What the Host App Provides

The host app (e.g., `bh-core`) provides **only configuration** — a bank mapping that tells DX Mirror which HindSight banks relate to which controllers/models. Everything else is engine-side.

---

## Architecture: Middleware Rewrite + Instrumentation Flag

```
Browser: GET /dx/mirror/products/2
    |
    v
DevExperience::DxMirror::Middleware          <-- registered by engine.rb initializer
    |  strips /dx/mirror prefix -> PATH_INFO = /products/2
    |  sets env["dx_mirror"] = true
    v
Normal Rails router -> ProductsController#show
    |  around_action detects dx_mirror flag (injected by engine initializer)
    |  activates AS::Notifications subscribers
    |  collects introspection data during render
    |  injects overlay via content_for(:head) + content_for(:footer)
    v
Response: identical HTML + introspection JSON + Stimulus controller
```

**Why middleware, not engine catch-all routes:** A catch-all inside the engine would require reimplementing or proxying every host controller. Middleware is transparent — it rewrites the URL, the normal Rails stack handles rendering, and a single flag activates introspection. No route duplication, no controller duplication, works automatically for all current and future host-app routes.

**Why the engine registers everything:** The engine's `initializer` block in `engine.rb` inserts the middleware, prepends the `around_action` concern to `ApplicationController`, and injects the helper module. The host app doesn't need to know the plumbing — it just mounts the engine at `/dx` and DX Mirror works.

---

## File Layout in dev-experience-coc-2026-q2

New files are namespaced under `dx_mirror/` within the existing engine structure:

```
vendor/dev-experience-coc-2026-q2/
  lib/
    dev_experience/
      dx_mirror.rb                      # Entry point, requires all modules
      dx_mirror/
        middleware.rb                   # Rack middleware (URL rewrite + flag)
        instrumenter.rb                 # AS::Notifications collector
        view_annotations.rb             # Comment-node wrapping for partials/components
        model_introspector.rb           # AR schema extraction
        controller_concern.rb           # around_action mixin for host ApplicationController
        helper.rb                       # View helper (dx_mirror_head_tags, dx_mirror_data_json)
        bank_mapping.rb                 # Controller/model -> HindSight bank resolution
        railtie.rb                      # Registers middleware + concern (dev-only)
  app/
    components/dev_experience/
      dx_mirror_modal/
        component.rb                    # Modal ViewComponent with tabs
        component.html.erb              # Modal HTML (Model|View|Controller|Agentic tabs)
      dx_mirror_schema_table/
        component.rb                    # Renders AR column/association table
        component.html.erb
      dx_mirror_source_list/
        component.rb                    # Renders file paths as vscode:// links
        component.html.erb
    controllers/dev_experience/
      introspect_controller.rb          # JSON endpoint for Agentic tab HindSight queries
    assets/
      stylesheets/dev_experience/
        dx_mirror.css                   # Modal + highlight styles
    javascript/
      controllers/dev_experience/
        dx_mirror_controller.js         # Stimulus: contextmenu, modal, tab switching, link rewriting
  config/
    routes.rb                           # Add introspect endpoint to existing engine routes
```

**Nothing new in the host app.** The engine handles everything via its railtie/initializer.

---

## Implementation Plan

### Phase 1: Middleware and Railtie

**1. `lib/dev_experience/dx_mirror/middleware.rb`**

```ruby
# frozen_string_literal: true

module DevExperience
  module DxMirror
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        if env["PATH_INFO"]&.start_with?("/dx/mirror")
          original_path = env["PATH_INFO"]
          env["PATH_INFO"] = env["PATH_INFO"].delete_prefix("/dx/mirror")
          env["PATH_INFO"] = "/" if env["PATH_INFO"].empty?
          env["dx_mirror"] = { original_path: original_path }
        end
        @app.call(env)
      end
    end
  end
end
```

**2. `lib/dev_experience/dx_mirror/railtie.rb`**

Registered by the engine only in development:

```ruby
# frozen_string_literal: true

module DevExperience
  module DxMirror
    class Railtie < ::Rails::Railtie
      initializer "dev_experience.dx_mirror", after: :load_config_initializers do |app|
        next unless Rails.env.development?

        app.middleware.insert_before(ActionDispatch::Static, Middleware)

        ActiveSupport.on_load(:action_controller_base) do
          include DevExperience::DxMirror::ControllerConcern
        end

        ActiveSupport.on_load(:action_view) do
          include DevExperience::DxMirror::Helper
        end
      end
    end
  end
end
```

**3. `lib/dev_experience/engine.rb`** (modify — add one require)

```ruby
require_relative "dx_mirror" if Rails.env.development?
```

**4. `config/routes.rb`** (modify — add introspect endpoint to existing engine routes)

```ruby
namespace :dx_mirror do
  post :introspect
end
```

### Phase 2: Introspection Data Collection

**5. `lib/dev_experience/dx_mirror/instrumenter.rb`**

Request-scoped collector using `ActiveSupport::Notifications`:

- `process_action.action_controller` -> controller class, action, before_actions, params, source_location
- `render_template.action_view` -> template identifier (full path)
- `render_partial.action_view` -> partial identifier
- `render.view_component` -> component class name
- `sql.active_record` -> table name, query count per model

Stores in `Thread.current[:dx_mirror_data]` (cleared in `deactivate`).

Data structure:
```ruby
{
  controller: { class_name:, action:, before_actions:, params:, file_path: },
  views: { template:, partials: [], layout:, components: [] },
  models: {
    "Product" => {
      table:, columns: { name: { type:, null:, default: } },
      associations: [{ type:, name:, class_name:, foreign_key: }],
      validations: [{ attribute:, kind:, options: }],
      file_path:, query_count:, record_count:
    }
  },
  agentic: { banks: [], available: true }
}
```

**6. `lib/dev_experience/dx_mirror/view_annotations.rb`**

When dx_mirror is active, prepend modules to:
- `ActionView::PartialRenderer` — wrap output with `<!-- dx:partial:path/to/_partial.html.erb -->...<!-- /dx:partial -->`
- `ViewComponent::Base#render_in` — wrap with `<!-- dx:component:ClassName -->...<!-- /dx:component -->`

Comment nodes are invisible in the rendered page but walkable by JS via `TreeWalker(NodeFilter.SHOW_COMMENT)`. This is a pragmatic boundary: we annotate at the partial/component level (automatable), not at individual `<%= %>` expressions (would require ERB source maps).

**7. `lib/dev_experience/dx_mirror/model_introspector.rb`**

Given an ActiveRecord class, extracts:
- `columns_hash` (name, type, null, default)
- `reflect_on_all_associations` (type, class_name, foreign_key)
- `validators` (attribute, kind, options)
- Source file via `const_source_location`

Called by the instrumenter after the action completes, by scanning controller instance variables for AR objects/relations.

**8. `lib/dev_experience/dx_mirror/bank_mapping.rb`**

Configurable mapping from controller/model context to HindSight bank IDs. The engine provides a default mapping based on the `dx:app:*` and `dx:template:*` banks it already syncs. The host app can extend it:

```ruby
# In bh-core config/initializers/dx_mirror.rb (optional host config)
DevExperience::DxMirror.configure do |config|
  config.bank_mapping = {
    "Product" => ["bh-catalog-products", "bh-catalog-categories", "bh-catalog-compatibility"],
    "ProductsController#index" => ["bh-catalog-categories", "bh-catalog-bundles"],
    "ProductsController#show" => ["bh-catalog-products", "bh-catalog-compatibility"]
  }
end
```

Default fallback always includes the `dx:app:<app_name>` bank from the engine's existing UML sync.

### Phase 3: Controller Concern and Helper

**9. `lib/dev_experience/dx_mirror/controller_concern.rb`**

Injected into host `ApplicationController` via `ActiveSupport.on_load`:

```ruby
# frozen_string_literal: true

module DevExperience
  module DxMirror
    module ControllerConcern
      extend ActiveSupport::Concern

      included do
        around_action :dx_mirror_wrap, if: -> { request.env["dx_mirror"] }
        helper_method :dx_mirror?
      end

      def dx_mirror?
        request.env["dx_mirror"].present?
      end

      private

      def dx_mirror_wrap
        Instrumenter.activate(request, self)
        yield
        Instrumenter.finalize(self)
      ensure
        Instrumenter.deactivate
      end
    end
  end
end
```

**10. `lib/dev_experience/dx_mirror/helper.rb`**

Injected into ActionView via `ActiveSupport.on_load`:

```ruby
# frozen_string_literal: true

module DevExperience
  module DxMirror
    module Helper
      def dx_mirror_overlay
        return unless dx_mirror?
        render(DevExperience::DxMirrorModal::Component.new(
          data: Instrumenter.to_hash
        ))
      end
    end
  end
end
```

The `around_action` in the concern calls `content_for(:footer) { dx_mirror_overlay }` and `content_for(:head) { dx_mirror_head_tags }` automatically. No host view modifications needed.

### Phase 4: ViewComponents

**11. `app/components/dev_experience/dx_mirror_modal/component.rb`**

```ruby
# frozen_string_literal: true

module DevExperience
  class DxMirrorModal::Component < ApplicationViewComponent
    option :data  # The introspection hash from Instrumenter
  end
end
```

**12. `app/components/dev_experience/dx_mirror_modal/component.html.erb`**

Modal skeleton:
- Hidden container div with `data-controller="dev-experience--dx-mirror"`
- Backdrop overlay (click-to-dismiss)
- Tabbed panel: **Model** | **View** | **Controller** | **Agentic**
- Each tab panel is a `data-dev-experience--dx-mirror-target`
- Embedded `<script type="application/json" id="dx-mirror-data">` with introspection JSON
- Close button (X), Escape key handler
- Model tab: schema table component
- View tab: source list component (vscode:// links)
- Controller tab: action details, before_actions, params
- Agentic tab: bank list + "Recall" button (fetches from introspect endpoint)

**13. `app/components/dev_experience/dx_mirror_schema_table/`**

Renders an AR model's columns and associations as a styled table. Reusable for any model.

**14. `app/components/dev_experience/dx_mirror_source_list/`**

Renders file paths as clickable `vscode://file/...` links. Used by both View and Controller tabs.

### Phase 5: Stimulus Controller

**15. `app/javascript/controllers/dev_experience/dx_mirror_controller.js`**

```
connect()
  - Parse introspection JSON from #dx-mirror-data
  - Listen for contextmenu on document

handleContextMenu(event)
  - event.preventDefault()
  - Walk up from event.target using TreeWalker(NodeFilter.SHOW_COMMENT)
    to find nearest <!-- dx:partial:... --> or <!-- dx:component:... -->
  - Populate modal tabs with context-specific data
  - Show modal centered

switchTab(event)
  - Toggle active tab, show/hide panels

loadAgentic(event)
  - Fetch POST /dx/dx_mirror/introspect with { bank_id, query }
  - Render returned memories into the Agentic panel

rewriteLinks()
  - On connect, intercept <a> clicks within the page
  - Rewrite href="/products/2" -> href="/dx/mirror/products/2"
  - Keep navigation within the mirror

dismiss()
  - Hide modal on Escape, backdrop click, or close button
```

### Phase 6: Agentic Endpoint

**16. `app/controllers/dev_experience/introspect_controller.rb`**

```ruby
# frozen_string_literal: true

module DevExperience
  class IntrospectController < ApplicationController
    def create
      bank_id = params.require(:bank_id)
      query = params.require(:query)
      result = Hindsight.client.memories.recall(bank_id, query, budget: "mid")
      render json: result
    end
  end
end
```

Namespaced inside the engine — endpoint is `/dx/dx_mirror/introspect`. The engine already handles auth context.

### Phase 7: Styles

**17. `app/assets/stylesheets/dev_experience/dx_mirror.css`**

- `.dx-mirror-backdrop` — fixed overlay, bg-black/50, backdrop-blur-sm
- `.dx-mirror-modal` — centered panel, max-w-3xl, rounded-2xl, shadow-xl, max-h-80vh overflow-auto
- `.dx-mirror-tabs` — flex row, border-b, matching existing tab styling
- `.dx-mirror-tab-active` — blue-600 border-b-2
- `.dx-mirror-content` — padding, monospace for code/paths
- `.dx-mirror-highlight` — subtle dashed outline on hovered annotated regions
- `.dx-mirror-vscode-link` — blue, underline, monospace, cursor-pointer

---

## Interaction with Other Vendor Gems

| Gem | Role in DX Mirror |
|---|---|
| **dev-experience-coc-2026-q2** | Home. Middleware, instrumenter, components, Stimulus, routes. |
| **engine-design-system** | Provides the base layout with `:head` and `:footer` content hooks that the mirror injects into. No modifications needed. |
| **hindsight** | Agentic tab calls `Hindsight.client.memories.recall()` to query banks. Already a dependency of dev-experience. |
| **context-record** | Future: introspection data could be wrapped as ContextRecord for cross-system tracing. Not needed for MVP. |
| **swift-view / swift-view-rails** | Future: Swift WASM components would get `<!-- dx:swift-component:... -->` annotations alongside ViewComponent annotations. |
| **cognition-client-api** | Future: the Agentic tab could show cognition callback history (which `client.context.history` / `client.inventory.query` calls were made for this page). |
| **rails-coc-2026-q2** | When it orchestrates cognition, the DX Mirror Agentic tab would show the full INITIALIZE/SERVE/SAVE lifecycle for the current session. |

---

## What the Host App Does (bh-core example)

The host app does almost nothing. It already mounts the engine:

```ruby
# config/routes.rb (already exists)
mount DevExperience::Engine, at: "/dx"
```

Optionally, it provides a bank mapping initializer:

```ruby
# config/initializers/dx_mirror.rb (optional, new)
DevExperience::DxMirror.configure do |config|
  config.bank_mapping = {
    "Product" => %w[bh-catalog-products bh-catalog-categories bh-catalog-compatibility],
    "ProductsController#index" => %w[bh-catalog-categories bh-catalog-bundles],
    "ProductsController#show" => %w[bh-catalog-products bh-catalog-compatibility]
  }
end
```

And adds a "Mirror" link to its tab navigation:

```erb
<%# app/views/application/_bh_tabs.html.erb (modify) %>
<a href="/dx/mirror<%= request.path %>"
   class="bh-tab <%= 'bh-tab-active' if request.env['dx_mirror'] %>">Mirror</a>
```

That's it. Three lines of config, one link.

---

## Files Summary

All paths relative to `vendor/dev-experience-coc-2026-q2/`:

| File | Action | Purpose |
|---|---|---|
| `lib/dev_experience/dx_mirror.rb` | New | Entry point, requires all modules |
| `lib/dev_experience/dx_mirror/middleware.rb` | New | Rack URL rewrite + flag |
| `lib/dev_experience/dx_mirror/railtie.rb` | New | Registers middleware + concerns (dev only) |
| `lib/dev_experience/dx_mirror/instrumenter.rb` | New | AS::Notifications collector |
| `lib/dev_experience/dx_mirror/view_annotations.rb` | New | Comment-node wrapping |
| `lib/dev_experience/dx_mirror/model_introspector.rb` | New | AR schema extraction |
| `lib/dev_experience/dx_mirror/controller_concern.rb` | New | around_action mixin |
| `lib/dev_experience/dx_mirror/helper.rb` | New | View helper for overlay injection |
| `lib/dev_experience/dx_mirror/bank_mapping.rb` | New | Controller/model -> HindSight bank map |
| `app/components/dev_experience/dx_mirror_modal/` | New | Modal ViewComponent (4 tabs) |
| `app/components/dev_experience/dx_mirror_schema_table/` | New | AR schema table component |
| `app/components/dev_experience/dx_mirror_source_list/` | New | File path list with vscode:// links |
| `app/javascript/controllers/dev_experience/dx_mirror_controller.js` | New | Stimulus: contextmenu + modal |
| `app/assets/stylesheets/dev_experience/dx_mirror.css` | New | Modal + highlight styles |
| `app/controllers/dev_experience/introspect_controller.rb` | New | HindSight recall JSON endpoint |
| `lib/dev_experience/engine.rb` | Modify | Require dx_mirror in development |
| `config/routes.rb` | Modify | Add introspect route |

Host app changes (e.g., `apps/bh-core/`):

| File | Action | Purpose |
|---|---|---|
| `config/initializers/dx_mirror.rb` | New (optional) | Bank mapping config |
| `app/views/application/_bh_tabs.html.erb` | Modify | Add "Mirror" tab link |

---

## Verification

1. `rails s` -> navigate to `/dx/mirror/products` — renders identical to `/products`
2. Right-click a product card -> modal opens with 4 tabs
3. **Model tab**: shows Product table with columns (name/string, price/decimal, sku/string, etc.)
4. **View tab**: shows `products/index.html.erb` -> `products/_product.html.erb` -> `EngineDesignSystem::CardComponent`, paths link to VS Code
5. **Controller tab**: shows `ProductsController#index`, `before_action :set_product` (on show), permitted params
6. **Agentic tab**: lists mapped HindSight banks, "Recall" button returns relevant memories from `bh-catalog-products`
7. Navigate to `/dx/mirror/products/1` -> same introspection for show action
8. All links within mirror stay within `/dx/mirror/` prefix
9. Regular `/products` pages are completely unaffected
10. `/dx/templates` and `/dx/apps` (existing DX routes) continue to work unchanged
