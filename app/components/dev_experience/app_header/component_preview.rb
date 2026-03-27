# frozen_string_literal: true

module DevExperience
  class AppHeader::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(id: 1, name: "rails-coc-2026-q2")
      app = App.new(
        name: "rcoc-human-user",
        template: template,
        repo_url: "https://github.com/laquereric/b-and-h"
      )
      render DevExperience::AppHeader::Component.new(app: app)
    end
  end
end
