# frozen_string_literal: true

module DevExperience
  module DxMirror
    module ControllerConcern
      extend ActiveSupport::Concern

      included do
        around_action :dx_mirror_wrap, if: -> { request.env["dx_mirror"] }
        helper_method :dx_mirror?

        after_action :dx_mirror_inject, if: -> { request.env["dx_mirror"] }
        after_action :dx_inject_link
      end

      def dx_mirror?
        request.env["dx_mirror"].present?
      end

      private

      def dx_mirror_wrap
        ViewAnnotations.install!
        Instrumenter.activate(request, self)
        yield
      rescue => e
        raise e
      ensure
        Instrumenter.deactivate unless e
      end

      def dx_mirror_inject
        return unless response.content_type&.include?("text/html")
        return if response.body.blank?

        Instrumenter.finalize(self)
        data_hash = Instrumenter.to_hash
        json_data = JSON.generate(data_hash)

        panel_html = DevExperience::DxMirrorModal::Component.new(data: data_hash).render_in(view_context)
        overlay_html = dx_mirror_build_overlay(json_data, panel_html)

        body = response.body
        body = body.sub("</head>", "#{dx_mirror_head_injection}</head>")
        body = body.sub("</body>", "#{overlay_html}</body>")
        response.body = body
      end

      def dx_inject_link
        return unless response.content_type&.include?("text/html")
        return if response.body.blank?

        body = response.body
        unless request.env["dx_mirror"]
          body = body.sub("</head>", %(<link rel="stylesheet" href="/dx/assets/dx_mirror.css"></head>))
        end
        body = body.sub("</body>", "#{dx_link_html}</body>")
        response.body = body
      end

      def dx_mirror_head_injection
        <<~HTML
          <link rel="stylesheet" href="/dx/assets/dx_mirror.css">
          <script type="module">
            // Register DX Mirror controller with the host app's Stimulus instance
            import("/dx/assets/dx_mirror.js").then(mod => {
              const app = window.Stimulus || document.querySelector("[data-controller]")?.__stimulusApplication
              if (app) {
                app.register("dx-mirror", mod.default)
              } else {
                // Fallback: wait for Stimulus to be available
                document.addEventListener("stimulus:load", () => {
                  window.Stimulus.register("dx-mirror", mod.default)
                })
              }
            }).catch(err => {
              console.warn("[DX Mirror] Could not load controller:", err)
            })
          </script>
        HTML
      end

      def dx_mirror_build_overlay(json_data, panel_html)
        <<~HTML
          <script type="application/json" id="dx-mirror-data" data-turbo-temporary>#{json_data}</script>
          <div id="dx-mirror-overlay"
               data-controller="dx-mirror"
               data-dx-mirror-introspect-url-value="/dx/dx_mirror/introspect"
               data-turbo-temporary
               style="display:none;">
            <div class="dx-mirror-backdrop" data-action="click->dx-mirror#dismiss"></div>
            <div class="dx-mirror-modal">
              <div class="dx-mirror-modal-header">
                <h2 class="dx-mirror-modal-title" data-dx-mirror-target="title">Source Inspector</h2>
                <button class="dx-mirror-close" data-action="click->dx-mirror#dismiss">&times;</button>
              </div>
              <nav class="dx-mirror-tabs">
                <button class="dx-mirror-tab dx-mirror-tab-active" data-action="click->dx-mirror#switchTab" data-tab="model">Model</button>
                <button class="dx-mirror-tab" data-action="click->dx-mirror#switchTab" data-tab="view">View</button>
                <button class="dx-mirror-tab" data-action="click->dx-mirror#switchTab" data-tab="controller">Controller</button>
                <button class="dx-mirror-tab" data-action="click->dx-mirror#switchTab" data-tab="agentic">Agentic</button>
                <button class="dx-mirror-tab" data-action="click->dx-mirror#switchTab" data-tab="help">Help</button>
              </nav>
              <div class="dx-mirror-panels">
                #{panel_html}
                #{dx_help_panel_html}
              </div>
            </div>
          </div>
        HTML
      end

      def dx_help_body_html
        <<~HTML
          <h3 class="dx-mirror-section-title">How to Use</h3>
          <p class="dx-mirror-help-text">
            <strong>Right-click</strong> any element on the page while in Mirror mode
            to inspect its source code, data models, controller actions, and agentic context.
          </p>
          <p class="dx-mirror-help-text">
            The inspector walks the DOM from your click target to find the nearest
            partial or ViewComponent, then shows you exactly what rendered that element.
          </p>
          <h3 class="dx-mirror-section-title">Tabs</h3>
          <ul class="dx-mirror-help-list">
            <li><strong>Model</strong> &mdash; Active Record models and their schema</li>
            <li><strong>View</strong> &mdash; Template, partials, components, and layout</li>
            <li><strong>Controller</strong> &mdash; Class, action, callbacks, and params</li>
            <li><strong>Agentic</strong> &mdash; HindSight memory banks for this context</li>
          </ul>
        HTML
      end

      def dx_chat_html(stimulus: false)
        send_attr = stimulus ? ' data-action="click->dx-mirror#sendChat"' : ""
        <<~HTML
          <h3 class="dx-mirror-section-title">Chat</h3>
          <div class="dx-mirror-chat">
            <p class="dx-mirror-help-text">Ask about this page's architecture:</p>
            <div class="dx-mirror-chat-row">
              <textarea class="dx-mirror-chat-input" placeholder="e.g. How does the product model relate to categories?" rows="2"></textarea>
              <button class="dx-mirror-recall-btn dx-mirror-chat-send"#{send_attr}>Send</button>
            </div>
          </div>
        HTML
      end

      def dx_help_panel_html
        <<~HTML
          <div data-panel="help" style="display:none;">
            #{dx_help_body_html}
            #{dx_chat_html(stimulus: true)}
          </div>
        HTML
      end

      def dx_link_html
        current_path = request.env.dig("dx_mirror", :rewritten_path) || request.path
        mirror_url = "/dx/mirror#{current_path}"
        in_mirror = request.env["dx_mirror"].present?

        mirror_cta = if in_mirror
                       '<p class="dx-mirror-help-text"><strong>You are in Mirror mode.</strong> Right-click any element to inspect it.</p>'
                     else
                       %(<a href="#{mirror_url}" class="dx-mirror-recall-btn" style="text-decoration:none;display:inline-block;">Enter Mirror Mode</a>)
                     end

        <<~HTML
          <div id="dx-link" class="dx-link" data-turbo-temporary>
            <button class="dx-link-btn" onclick="document.getElementById('dx-link-modal').style.display=document.getElementById('dx-link-modal').style.display==='flex'?'none':'flex'">dx</button>
          </div>
          <div id="dx-link-modal" class="dx-link-modal-overlay" data-turbo-temporary style="display:none;" onclick="if(event.target===this)this.style.display='none'">
            <div class="dx-mirror-modal" style="max-width:36rem;">
              <div class="dx-mirror-modal-header">
                <h2 class="dx-mirror-modal-title">Page Reverse Engineering</h2>
                <button class="dx-mirror-close" onclick="document.getElementById('dx-link-modal').style.display='none'">&times;</button>
              </div>
              <nav class="dx-mirror-tabs" id="dx-link-tabs">
                <button class="dx-mirror-tab dx-mirror-tab-active" onclick="DxLink.switchTab(this,'overview')">Overview</button>
                <button class="dx-mirror-tab" onclick="DxLink.switchTab(this,'help')">Help</button>
              </nav>
              <div class="dx-mirror-panels">
                <div data-panel="overview">
                  <p class="dx-mirror-help-text" style="margin-bottom:0.75rem;">
                    <strong>DX Mirror</strong> lets you reverse-engineer any page in this application.
                    It reveals the models, views, controllers, and agentic context behind what you see.
                  </p>
                  <p class="dx-mirror-help-text" style="margin-bottom:1rem;">
                    Current page: <code>#{current_path}</code>
                  </p>
                  #{mirror_cta}
                </div>
                <div data-panel="help" style="display:none;">
                  #{dx_help_body_html}
                  #{dx_chat_html(stimulus: false)}
                </div>
              </div>
            </div>
          </div>
          <script>
            window.DxLink={switchTab:function(btn,name){btn.parentElement.querySelectorAll('.dx-mirror-tab').forEach(function(t){t.classList.toggle('dx-mirror-tab-active',t===btn)});btn.parentElement.nextElementSibling.querySelectorAll('[data-panel]').forEach(function(p){p.style.display=p.dataset.panel===name?'':'none'})}};
          </script>
        HTML
      end
    end
  end
end
