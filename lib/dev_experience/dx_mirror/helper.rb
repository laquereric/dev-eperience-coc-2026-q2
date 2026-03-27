# frozen_string_literal: true

module DevExperience
  module DxMirror
    module Helper
      def dx_mirror?
        request.env["dx_mirror"].present?
      rescue
        false
      end

      def dx_mirror_original_path
        request.env.dig("dx_mirror", :original_path)
      end

      def dx_mirror_link(path)
        "/dx/mirror#{path}"
      end
    end
  end
end
