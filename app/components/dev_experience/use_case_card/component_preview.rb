# frozen_string_literal: true

module DevExperience
  class UseCaseCard::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      uc = UseCase.new(
        identifier: "UC-1",
        name: "Authenticate",
        description: "User authenticates with the system",
        owner: template
      )
      uc.actors.build(name: "User", owner: template)
      render DevExperience::UseCaseCard::Component.new(use_case: uc)
    end

    # @label With implements
    def with_implements
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      app = App.new(id: 1, name: "rcoc-human-customer", template: template)
      parent_uc = UseCase.new(identifier: "UC-1", name: "Authenticate", owner: template)
      uc = UseCase.new(
        identifier: "UC-1",
        name: "User Login",
        description: "User logs in via email/password",
        owner: app,
        implements: parent_uc
      )
      render DevExperience::UseCaseCard::Component.new(use_case: uc)
    end
  end
end
