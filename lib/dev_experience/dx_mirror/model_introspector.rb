# frozen_string_literal: true

module DevExperience
  module DxMirror
    module ModelIntrospector
      class << self
        def introspect(klass)
          {
            table: klass.table_name,
            columns: extract_columns(klass),
            associations: extract_associations(klass),
            validations: extract_validations(klass),
            file_path: source_location(klass)
          }
        end

        private

        def extract_columns(klass)
          klass.columns_hash.transform_values do |col|
            { type: col.type.to_s, null: col.null, default: col.default }
          end
        end

        def extract_associations(klass)
          klass.reflect_on_all_associations.map do |assoc|
            {
              type: assoc.macro.to_s,
              name: assoc.name.to_s,
              class_name: assoc.class_name,
              foreign_key: assoc.foreign_key.to_s
            }
          rescue => e
            { type: assoc.macro.to_s, name: assoc.name.to_s, error: e.message }
          end
        end

        def extract_validations(klass)
          klass.validators.map do |v|
            {
              attributes: v.attributes.map(&:to_s),
              kind: v.kind.to_s,
              options: v.options.except(:if, :unless).transform_values(&:to_s)
            }
          end
        end

        def source_location(klass)
          Object.const_source_location(klass.name)&.first
        rescue
          nil
        end
      end
    end
  end
end
