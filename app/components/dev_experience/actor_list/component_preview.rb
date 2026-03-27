# frozen_string_literal: true

module DevExperience
  class ActorList::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      actors = [
        Actor.new(name: "User", description: "A human end-user", owner: template),
        Actor.new(name: "Human_Agent", description: "A human support agent", owner: template),
        Actor.new(name: "AI_Agent", description: "An AI-powered assistant", owner: template)
      ]
      render DevExperience::ActorList::Component.new(actors: actors)
    end
  end
end
