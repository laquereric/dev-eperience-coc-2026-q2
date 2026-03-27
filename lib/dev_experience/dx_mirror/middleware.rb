# frozen_string_literal: true

module DevExperience
  module DxMirror
    class Middleware
      PREFIX = "/dx/mirror"
      CSS_PATH = "/dx/assets/dx_mirror.css"
      JS_PATH = "/dx/assets/dx_mirror.js"

      def initialize(app)
        @app = app
        @css_file = File.expand_path("../../../app/assets/stylesheets/dev_experience/dx_mirror.css", __dir__)
        @js_file = File.expand_path("../../../app/javascript/controllers/dev_experience/dx_mirror_controller.js", __dir__)
      end

      def call(env)
        path = env["PATH_INFO"]

        case path
        when CSS_PATH
          serve_file(@css_file, "text/css")
        when JS_PATH
          serve_file(@js_file, "application/javascript")
        when /\A#{Regexp.escape(PREFIX)}(\/.*)?/
          original_path = path
          rewritten = path.delete_prefix(PREFIX)
          rewritten = "/" if rewritten.empty?

          env["PATH_INFO"] = rewritten
          env["REQUEST_PATH"] = rewritten if env["REQUEST_PATH"]
          env["dx_mirror"] = { original_path: original_path, rewritten_path: rewritten }

          @app.call(env)
        else
          @app.call(env)
        end
      end

      private

      def serve_file(file_path, content_type)
        if File.exist?(file_path)
          body = File.read(file_path)
          [200, { "Content-Type" => content_type, "Cache-Control" => "no-cache" }, [body]]
        else
          [404, { "Content-Type" => "text/plain" }, ["Not found"]]
        end
      end
    end
  end
end
