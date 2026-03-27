# frozen_string_literal: true

module DevExperience
  module DxMirror
    # Wraps partial and ViewComponent renders with HTML comment markers
    # when DX Mirror is active. These comments are invisible in the
    # rendered page but walkable by the Stimulus controller via TreeWalker.
    module ViewAnnotations
      module PartialRendererPatch
        def render(partial, view, block)
          result = super

          if Thread.current[:dx_mirror_data] && partial.respond_to?(:identifier)
            path = partial.identifier.to_s.sub(Rails.root.to_s + "/", "")
            result = "<!-- dx:partial:#{path} -->#{result}<!-- /dx:partial -->".html_safe
          end

          result
        end
      end

      module ViewComponentPatch
        def render_in(view_context, &block)
          result = super

          if Thread.current[:dx_mirror_data]
            name = self.class.name
            result = "<!-- dx:component:#{name} -->#{result}<!-- /dx:component -->".html_safe
          end

          result
        end
      end

      class << self
        def install!
          return if @installed

          if defined?(ActionView::PartialRenderer)
            ActionView::PartialRenderer.prepend(PartialRendererPatch)
          end

          if defined?(ViewComponent::Base)
            ViewComponent::Base.prepend(ViewComponentPatch)
          end

          @installed = true
        end
      end
    end
  end
end
