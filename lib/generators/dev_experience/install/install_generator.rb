# frozen_string_literal: true

module DevExperience
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Copy DevExperience migrations and mount the engine"

      def copy_migrations
        rake "dev_experience:install:migrations"
      end

      def mount_engine
        route 'mount DevExperience::Engine, at: "/dx"'
      end

      def display_post_install
        say ""
        say "DevExperience engine installed!", :green
        say "  Run: bin/rails db:migrate"
        say "  Engine mounted at: /dx"
        say ""
      end
    end
  end
end
