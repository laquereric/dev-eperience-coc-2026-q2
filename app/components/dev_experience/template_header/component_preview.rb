# frozen_string_literal: true

module DevExperience
  class TemplateHeader::ComponentPreview < ViewComponent::Preview
    # @label Default
    def default
      template = Template.new(
        name: "rails-coc-2026-q2",
        description: "Rails Chain of Custody Q2 2026 — platform-level UML specs",
        repo_url: "https://github.com/laquereric/rails-coc-2026-q2"
      )
      render DevExperience::TemplateHeader::Component.new(template: template)
    end

    # @label Minimal
    def minimal
      template = Template.new(name: "minimal-template")
      render DevExperience::TemplateHeader::Component.new(template: template)
    end
  end
end
