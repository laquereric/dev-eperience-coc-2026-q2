# frozen_string_literal: true

module DevExperience
  class UseCaseList::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      use_cases = [
        UseCase.new(identifier: "UC-1", name: "Authenticate", description: "User authenticates", owner: template),
        UseCase.new(identifier: "UC-2", name: "Browse Catalog", description: "User browses products", owner: template),
        UseCase.new(identifier: "UC-3", name: "Request Help", description: "User requests agent assistance", owner: template)
      ]
      render DevExperience::UseCaseList::Component.new(use_cases: use_cases)
    end
  end
end
