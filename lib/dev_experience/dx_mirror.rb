# frozen_string_literal: true

require_relative "dx_mirror/middleware"
require_relative "dx_mirror/instrumenter"
require_relative "dx_mirror/view_annotations"
require_relative "dx_mirror/model_introspector"
require_relative "dx_mirror/controller_concern"
require_relative "dx_mirror/helper"
require_relative "dx_mirror/bank_mapping"
require_relative "dx_mirror/railtie"

module DevExperience
  module DxMirror
    class << self
      def configure
        yield(configuration)
      end

      def configuration
        @configuration ||= Configuration.new
      end
    end

    class Configuration
      attr_accessor :bank_mapping

      def initialize
        @bank_mapping = {}
      end
    end
  end
end
