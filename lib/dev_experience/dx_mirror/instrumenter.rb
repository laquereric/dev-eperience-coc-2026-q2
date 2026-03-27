# frozen_string_literal: true

module DevExperience
  module DxMirror
    # Request-scoped collector that subscribes to ActiveSupport::Notifications
    # during a DX Mirror request and gathers controller, view, model, and
    # agentic introspection data.
    module Instrumenter
      THREAD_KEY = :dx_mirror_data

      class << self
        def activate(request, controller)
          data = {
            controller: {},
            views: { template: nil, partials: [], layout: nil, components: [] },
            models: {},
            agentic: { banks: [], available: defined?(Hindsight) }
          }
          Thread.current[THREAD_KEY] = data

          subscribe_notifications
          collect_controller_data(controller)
        end

        def finalize(controller)
          data = Thread.current[THREAD_KEY]
          return unless data

          collect_model_data(controller)
          resolve_banks(controller)
        end

        def deactivate
          unsubscribe_notifications
          Thread.current[THREAD_KEY] = nil
        end

        def to_hash
          Thread.current[THREAD_KEY] || {}
        end

        def to_json
          require "json"
          JSON.generate(to_hash)
        end

        def active?
          Thread.current[THREAD_KEY].present?
        end

        private

        def collect_controller_data(controller)
          data = Thread.current[THREAD_KEY]
          klass = controller.class

          callbacks = klass._process_action_callbacks.select { |cb| cb.kind == :before }.map do |cb|
            cb.filter.to_s
          end

          file_path = begin
            Object.const_source_location(klass.name)&.first
          rescue
            nil
          end

          data[:controller] = {
            class_name: klass.name,
            action: controller.action_name,
            before_actions: callbacks,
            params: controller.params.to_unsafe_h.except("controller", "action"),
            file_path: file_path
          }
        end

        def collect_model_data(controller)
          data = Thread.current[THREAD_KEY]

          controller.instance_variables.each do |ivar|
            val = controller.instance_variable_get(ivar)
            introspect_value(data, val)
          end
        end

        def introspect_value(data, val)
          case val
          when ActiveRecord::Base
            add_model_info(data, val.class, record_count: 1)
          when ActiveRecord::Relation
            add_model_info(data, val.klass, record_count: val.loaded? ? val.size : nil)
          when Array
            val.first(1).each do |item|
              introspect_value(data, item) if item.is_a?(ActiveRecord::Base)
            end
          end
        end

        def add_model_info(data, klass, record_count: nil)
          name = klass.name
          return if data[:models].key?(name)

          data[:models][name] = ModelIntrospector.introspect(klass).merge(
            record_count: record_count
          )
        end

        def resolve_banks(controller)
          data = Thread.current[THREAD_KEY]
          mapping = DxMirror.configuration.bank_mapping
          key = "#{data[:controller][:class_name]}##{data[:controller][:action]}"

          banks = mapping[key] || []
          data[:models].each_key do |model_name|
            banks += (mapping[model_name] || [])
          end

          app_name = Rails.application.class.module_parent_name.underscore.dasherize
          banks << "dx:app:#{app_name}"
          data[:agentic][:banks] = banks.uniq
        end

        def subscribe_notifications
          @subscriptions = []

          @subscriptions << ActiveSupport::Notifications.subscribe("render_template.action_view") do |_name, _start, _finish, _id, payload|
            next unless active?
            data = Thread.current[THREAD_KEY]
            data[:views][:template] = normalize_path(payload[:identifier])
            data[:views][:layout] = normalize_path(payload[:layout]) if payload[:layout]
          end

          @subscriptions << ActiveSupport::Notifications.subscribe("render_partial.action_view") do |_name, _start, _finish, _id, payload|
            next unless active?
            data = Thread.current[THREAD_KEY]
            path = normalize_path(payload[:identifier])
            data[:views][:partials] << path unless data[:views][:partials].include?(path)
          end

          @subscriptions << ActiveSupport::Notifications.subscribe("render.view_component") do |_name, _start, _finish, _id, payload|
            next unless active?
            data = Thread.current[THREAD_KEY]
            component_name = payload[:name] || payload[:identifier]
            data[:views][:components] << component_name unless data[:views][:components].include?(component_name)
          end
        end

        def unsubscribe_notifications
          return unless @subscriptions

          @subscriptions.each { |sub| ActiveSupport::Notifications.unsubscribe(sub) }
          @subscriptions = nil
        end

        def normalize_path(path)
          return nil unless path

          path.to_s.sub(Rails.root.to_s + "/", "")
        end
      end
    end
  end
end
