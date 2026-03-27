# frozen_string_literal: true

require "hindsight"
require "view_component"
require "view_component/contrib"
require "dry-initializer"
require_relative "dev_experience/engine"
require_relative "dev_experience/uml_sync"
require_relative "dev_experience/uml_import"

module DevExperience
  VERSION = File.read(File.expand_path("../../VERSION", __FILE__)).strip rescue "0.0.0"
end
