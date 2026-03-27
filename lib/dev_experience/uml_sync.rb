# frozen_string_literal: true

module DevExperience
  # Syncs UML spec files (ACTORS.md, USE_CASES.md, SEQUENCES.md) into
  # Hindsight memory banks. Each Template or App gets its own bank.
  #
  # Bank naming: "dx:<owner_type>:<name>"
  #   e.g. "dx:template:rails-coc-2026-q2"
  #   e.g. "dx:app:rcoc-human-user"
  module UmlSync
    SPEC_FILES = %w[ACTORS.md USE_CASES.md SEQUENCES.md].freeze
    PREFIXED_SPEC_FILES = ->(prefix) {
      SPEC_FILES.map { |f| "#{prefix}_#{f}" } + SPEC_FILES
    }

    class << self
      # Sync a directory of UML specs into a Hindsight bank.
      #
      # @param path [String] directory containing spec files
      # @param bank_id [String] Hindsight bank ID
      # @param tags [Array<String>] optional tags for all memories
      # @param client [Hindsight::Client] optional client override
      def sync(path:, bank_id:, tags: [], client: Hindsight.client)
        items = collect_items(path, tags)

        if items.empty?
          puts "  No spec files found in #{path}"
          return
        end

        ensure_bank(client, bank_id)

        result = client.retain(bank_id, items)
        puts "  Synced #{items.length} items to bank '#{bank_id}' (#{result['items_count'] || items.length} retained)"
        result
      end

      # Sync a Template directory (looks for RCOC_ACTORS.md etc and ACTORS.md)
      def sync_template(path:, name:, client: Hindsight.client)
        bank_id = "dx:template:#{name}"
        tags = ["template:#{name}"]
        puts "Syncing template '#{name}' from #{path}"
        sync(path: path, bank_id: bank_id, tags: tags, client: client)
      end

      # Sync an App directory
      def sync_app(path:, name:, template_name: nil, client: Hindsight.client)
        bank_id = "dx:app:#{name}"
        tags = ["app:#{name}"]
        tags << "template:#{template_name}" if template_name
        puts "Syncing app '#{name}' from #{path}"
        sync(path: path, bank_id: bank_id, tags: tags, client: client)
      end

      private

      def ensure_bank(client, bank_id)
        client.banks.get(bank_id)
      rescue Hindsight::NotFoundError
        client.banks.create(bank_id, name: bank_id,
          retain_mission: "Extract UML actors, use cases, sequences, and their relationships. " \
                          "Preserve actor names exactly (e.g. AI_Agent, Human_Agent). " \
                          "Track implements/inherits relationships between template and app specs.")
      end

      def collect_items(path, tags)
        items = []

        find_spec_files(path).each do |file|
          content = File.read(file)
          next if content.strip.empty?

          basename = File.basename(file, ".md")
          spec_type = detect_spec_type(basename)

          items << {
            content: content,
            context: "uml:#{spec_type}",
            document_id: "#{File.basename(path)}:#{basename}",
            tags: tags + ["spec_type:#{spec_type}"],
            metadata: {
              file: file,
              spec_type: spec_type,
              basename: basename
            }
          }
        end

        items
      end

      def find_spec_files(path)
        Dir.glob(File.join(path, "*.md")).select do |f|
          basename = File.basename(f, ".md").upcase
          basename.end_with?("ACTORS", "USE_CASES", "SEQUENCES") ||
            basename == "ACTORS" || basename == "USE_CASES" || basename == "SEQUENCES"
        end
      end

      def detect_spec_type(basename)
        upper = basename.upcase
        if upper.end_with?("ACTORS")
          "actors"
        elsif upper.end_with?("USE_CASES")
          "use_cases"
        elsif upper.end_with?("SEQUENCES")
          "sequences"
        else
          "unknown"
        end
      end
    end
  end
end
