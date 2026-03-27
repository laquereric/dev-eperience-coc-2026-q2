# frozen_string_literal: true

module DevExperience
  module DxMirror
    class Railtie < ::Rails::Railtie
      initializer "dev_experience.dx_mirror" do |app|
        next unless Rails.env.development?

        app.middleware.insert_before(ActionDispatch::Static, DevExperience::DxMirror::Middleware)

        ActiveSupport.on_load(:action_controller_base) do
          include DevExperience::DxMirror::ControllerConcern
        end

        ActiveSupport.on_load(:action_view) do
          include DevExperience::DxMirror::Helper
        end
      end
    end
  end
end
