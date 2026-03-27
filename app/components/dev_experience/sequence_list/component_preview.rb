# frozen_string_literal: true

module DevExperience
  class SequenceList::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      user = Actor.new(id: 1, name: "User", owner: template)
      agent = Actor.new(id: 2, name: "AI_Agent", owner: template)

      seq1 = Sequence.new(name: "Session Establishment", owner: template)
      seq1.steps.build(position: 1, from_actor: user, to_actor: agent, action: "requests_session")
      seq1.steps.build(position: 2, from_actor: agent, to_actor: user, action: "confirms_session")

      seq2 = Sequence.new(name: "Help Request", owner: template)
      seq2.steps.build(position: 1, from_actor: user, to_actor: agent, action: "asks_for_help")
      seq2.steps.build(position: 2, from_actor: agent, to_actor: user, action: "provides_answer")

      render DevExperience::SequenceList::Component.new(sequences: [seq1, seq2])
    end
  end
end
