# frozen_string_literal: true

module DevExperience
  class Engine < ::Rails::Engine
    isolate_namespace DevExperience

    initializer "dev_experience.view_component" do
      ActiveSupport.on_load(:view_component) do
        # Enable sidecar pattern for engine components
        ViewComponent::Base.config.view_component_path = "app/components"
      end
    end

    initializer "dev_experience.autoload" do |app|
      app.config.autoload_paths << root.join("app", "components")
    end

    rake_tasks do
      load File.expand_path("../tasks/hindsight.rake", __dir__)
    end
  end
end
