# frozen_string_literal: true

# dev-experience-coc-2026-q2 Application Template
#
# Usage:
#   rails new my_app --database=sqlite3 --css=tailwind \
#     --template=https://github.com/laquereric/dev-experience-coc-2026-q2/app_template.rb
#
# What it does:
#   1. Adds the dev-experience-coc-2026-q2 engine gem
#   2. Installs ViewComponent + view_component-contrib + Lookbook
#   3. Configures RSpec, Stimulus, Tailwind for components
#   4. Mounts the engine at /dx as the ONLY top-level route
#   5. Creates a custom ViewComponent generator (sidecar pattern)
#
# Based on: https://railsbytes.com/script/zJosO5 (view_component-contrib template)

# -----------------------------------------------------------------------------
# 1. Engine dependency
# -----------------------------------------------------------------------------

gem "dev_experience", path: "vendor/dev-experience-coc-2026-q2"
gem "hindsight", path: "vendor/hindsight"

say_status :info, "Added dev-experience-coc-2026-q2 engine + hindsight gem"

# -----------------------------------------------------------------------------
# 2. ViewComponent gems
# -----------------------------------------------------------------------------

run "bundle add view_component view_component-contrib --skip-install"
run "bundle add lookbook --group development --skip-install"
run "bundle add dry-initializer --skip-install"

say_status :info, "ViewComponent gems added"

# -----------------------------------------------------------------------------
# 3. Component paths
# -----------------------------------------------------------------------------

ROOT_PATH = "app/frontend/components"

root_paths = ROOT_PATH.split("/").map { |path| "\"#{path}\"" }.join(", ")

application "config.view_component.preview_paths << Rails.root.join(#{root_paths})"
application "config.autoload_paths << Rails.root.join(#{root_paths})"

say_status :info, "ViewComponent paths configured"

# -----------------------------------------------------------------------------
# 4. Base component classes
# -----------------------------------------------------------------------------

file "#{ROOT_PATH}/application_view_component.rb", <<~RUBY
  class ApplicationViewComponent < ViewComponentContrib::Base
    extend Dry::Initializer
  end
RUBY

file "#{ROOT_PATH}/application_view_component_preview.rb", <<~RUBY
  class ApplicationViewComponentPreview < ViewComponentContrib::Preview::Base
    self.abstract_class = true
  end
RUBY

say_status :info, "ApplicationViewComponent classes created"

# -----------------------------------------------------------------------------
# 4b. Hindsight initializer
# -----------------------------------------------------------------------------

initializer "hindsight.rb", <<~RUBY
  Hindsight.configure do |config|
    config.base_url = ENV.fetch("HINDSIGHT_BASE_URL", "http://localhost:8888")
    config.auth_token = ENV["HINDSIGHT_AUTH_TOKEN"]
  end
RUBY

say_status :info, "Hindsight configured (reads HINDSIGHT_BASE_URL, HINDSIGHT_AUTH_TOKEN from env)"

# -----------------------------------------------------------------------------
# 5. ViewComponent initializer
# -----------------------------------------------------------------------------

initializer "view_component.rb", <<~RUBY
  ActiveSupport.on_load(:view_component) do
    ViewComponent::Preview.extend ViewComponentContrib::Preview::Sidecarable
    ViewComponent::Preview.extend ViewComponentContrib::Preview::Abstract
  end
RUBY

# -----------------------------------------------------------------------------
# 6. RSpec configuration (if present)
# -----------------------------------------------------------------------------

USE_RSPEC = File.directory?("spec")
TEST_ROOT_PATH = USE_RSPEC ? File.join("spec", ROOT_PATH.sub("app/", "")) : File.join("test", ROOT_PATH.sub("app/", ""))
TEST_SYSTEM_ROOT_PATH = USE_RSPEC ? File.join("spec", "system", ROOT_PATH.sub("app/", "")) : File.join("test", "system", ROOT_PATH.sub("app/", ""))
TEST_SUFFIX = USE_RSPEC ? "spec" : "test"

if USE_RSPEC
  inject_into_file "spec/rails_helper.rb", after: "require \"rspec/rails\"\n" do
    "require \"capybara/rspec\"\nrequire \"view_component/test_helpers\"\n"
  end

  inject_into_file "spec/rails_helper.rb", after: "RSpec.configure do |config|\n" do
    <<-CODE
  config.include ViewComponent::TestHelpers, type: :view_component
  config.include Capybara::RSpecMatchers, type: :view_component

  config.define_derived_metadata(file_path: %r{/#{TEST_ROOT_PATH}}) do |metadata|
    metadata[:type] = :view_component
  end

    CODE
  end

  say_status :info, "RSpec configured for ViewComponent"
end

# -----------------------------------------------------------------------------
# 7. Routes — engine is the ONLY top-level route
# -----------------------------------------------------------------------------

route <<~RUBY
  # dev-experience engine is the sole top-level route
  mount DevExperience::Engine, at: "/dx"

  root to: redirect("/dx")
RUBY

gsub_file "config/routes.rb", /^\s*# Define your application routes.*$/, ""
gsub_file "config/routes.rb", /^\s*# Reveal health status on.*$/, ""
gsub_file "config/routes.rb", /^\s*# Render dynamic PWA files.*$/, ""
gsub_file "config/routes.rb", /^\s*get "up".*$/, ""
gsub_file "config/routes.rb", /^\s*get "service-worker".*$/, ""
gsub_file "config/routes.rb", /^\s*get "manifest".*$/, ""

say_status :info, "Routes configured — engine mounted at /dx"

# -----------------------------------------------------------------------------
# 8. ViewComponent generator (sidecar pattern, ERB, dry-initializer)
# -----------------------------------------------------------------------------

TEMPLATE_EXT = ".erb"

file "lib/generators/view_component/view_component_generator.rb", <<~CODE
  # frozen_string_literal: true

  class ViewComponentGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    class_option :skip_test, type: :boolean, default: false
    class_option :skip_system_test, type: :boolean, default: false
    class_option :skip_preview, type: :boolean, default: false

    argument :attributes, type: :array, default: [], banner: "attribute"

    def create_component_file
      template "component.rb", File.join("#{ROOT_PATH}", class_path, file_name, "component.rb")
    end

    def create_template_file
      template "component.html#{TEMPLATE_EXT}", File.join("#{ROOT_PATH}", class_path, file_name, "component.html#{TEMPLATE_EXT}")
    end

    def create_test_file
      return if options[:skip_test]

      template "component_#{TEST_SUFFIX}.rb", File.join("#{TEST_ROOT_PATH}", class_path, "\#{file_name}_#{TEST_SUFFIX}.rb")
    end

    def create_system_test_file
      return if options[:skip_system_test]

      template "component_system_#{TEST_SUFFIX}.rb", File.join("#{TEST_SYSTEM_ROOT_PATH}", class_path, "\#{file_name}_#{TEST_SUFFIX}.rb")
    end

    def create_preview_file
      return if options[:skip_preview]

      template "preview.rb", File.join("#{ROOT_PATH}", class_path, file_name, "preview.rb")
    end

    private

    def parent_class
      "ApplicationViewComponent"
    end

    def preview_parent_class
      "ApplicationViewComponentPreview"
    end

    def initialize_signature
      return if attributes.blank?

      attributes.map { |attr| "option :\#{attr.name}" }.join("\\n  ")
    end
  end
CODE

file "lib/generators/view_component/templates/component.rb.tt", <<~CODE
  # frozen_string_literal: true

  class <%= class_name %>::Component < <%= parent_class %>
    with_collection_parameter :<%= singular_name %>
  <%- if initialize_signature -%>
    <%= initialize_signature %>
  <%- end -%>
  end
CODE

file "lib/generators/view_component/templates/component.html.erb.tt", <<~CODE
  <div>Add <%= class_name %> template here</div>
CODE

file "lib/generators/view_component/templates/preview.rb.tt", <<~CODE
  # frozen_string_literal: true

  class <%= class_name %>::Preview < <%= preview_parent_class %>
    def default
    end
  end
CODE

if USE_RSPEC
  file "lib/generators/view_component/templates/component_spec.rb.tt", <<~CODE
    # frozen_string_literal: true

    require "rails_helper"

    describe <%= class_name %>::Component do
      let(:options) { {} }
      let(:component) { <%= class_name %>::Component.new(**options) }

      subject { rendered_content }

      it "renders" do
        render_inline(component)

        is_expected.to have_css "div"
      end
    end
  CODE

  file "lib/generators/view_component/templates/component_system_spec.rb.tt", <<~CODE
    # frozen_string_literal: true

    require "rails_helper"

    describe "<%= file_name %> component" do
      it "default preview" do
        visit("/rails/view_components<%= File.join(class_path, file_name) %>/default")
      end
    end
  CODE
else
  file "lib/generators/view_component/templates/component_test.rb.tt", <<~CODE
    # frozen_string_literal: true

    require "test_helper"

    class <%= class_name %>::ComponentTest < ViewComponent::TestCase
      def test_renders
        render_inline(<%= class_name %>::Component.new)

        assert_selector "div"
      end
    end
  CODE

  file "lib/generators/view_component/templates/component_system_test.rb.tt", <<~CODE
    # frozen_string_literal: true

    require "application_system_test_case"

    class <%= class_name %>::ComponentSystemTest < ApplicationSystemTestCase
      def test_default_preview
        visit("/rails/view_components<%= File.join(class_path, file_name) %>/default")
      end
    end
  CODE
end

file "lib/generators/view_component/USAGE", <<~CODE
  Description:
  ============
      Creates a new view component, test and preview files.
      Pass the component name, either CamelCased or under_scored, and an optional list of attributes as arguments.

  Example:
  ========
      bin/rails generate view_component Profile name age

      creates a Profile component and test:
          Component:    #{ROOT_PATH}/profile/component.rb
          Template:     #{ROOT_PATH}/profile/component.html#{TEMPLATE_EXT}
          Test:         #{TEST_ROOT_PATH}/profile_component_#{TEST_SUFFIX}.rb
          System Test:  #{TEST_SYSTEM_ROOT_PATH}/profile_component_#{TEST_SUFFIX}.rb
          Preview:      #{ROOT_PATH}/profile/component_preview.rb
CODE

say_status :info, "ViewComponent generator created"

# Check if autoload_lib is configured
if File.file?("config/application.rb") && File.read("config/application.rb").include?("config.autoload_lib")
  say_status :warning, "Make sure autoload_lib ignores lib/generators"
end

# -----------------------------------------------------------------------------
# 9. Install
# -----------------------------------------------------------------------------

say "Installing gems..."

Bundler.with_unbundled_env { run "bundle install" }

say_status :info, "Done! Run `bin/rails server` and visit http://localhost:3000/dx"
