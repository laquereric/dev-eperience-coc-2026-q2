# frozen_string_literal: true

module DevExperience
  class ActorCard::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      actor = Actor.new(name: "User", description: "A human end-user of the application", owner: template)
      render DevExperience::ActorCard::Component.new(actor: actor)
    end

    # @label Minimal
    def minimal
      app = App.new(id: 1, name: "rcoc-human-user", template: Template.new(name: "rails-coc-2026-q2"))
      actor = Actor.new(name: "AI_Agent", owner: app)
      render DevExperience::ActorCard::Component.new(actor: actor)
    end
  end
end
