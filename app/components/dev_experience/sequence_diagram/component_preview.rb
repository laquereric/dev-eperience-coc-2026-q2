# frozen_string_literal: true

module DevExperience
  class SequenceDiagram::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      user = Actor.new(id: 1, name: "User", owner: template)
      agent = Actor.new(id: 2, name: "AI_Agent", owner: template)
      system = Actor.new(id: 3, name: "System", owner: template)

      sequence = Sequence.new(name: "Session Establishment", owner: template)
      sequence.steps.build(position: 1, from_actor: user, to_actor: system, action: "logs_into")
      sequence.steps.build(position: 2, from_actor: system, to_actor: agent, action: "notifies")
      sequence.steps.build(position: 3, from_actor: agent, to_actor: user, action: "offers_help")

      render DevExperience::SequenceDiagram::Component.new(sequence: sequence)
    end
  end
end
