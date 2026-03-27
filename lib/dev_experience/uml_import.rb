# frozen_string_literal: true

module DevExperience
  # Parses ACTORS.md, USE_CASES.md, and SEQUENCES.md markdown files
  # and creates corresponding database records.
  #
  # Supports both standard names (ACTORS.md) and prefixed variants (RCOC_ACTORS.md).
  module UmlImport
    SPEC_PATTERNS = {
      actors: /(?:^|\/)(?:\w+_)?ACTORS\.md$/,
      use_cases: /(?:^|\/)(?:\w+_)?USE_CASES\.md$/,
      sequences: /(?:^|\/)(?:\w+_)?SEQUENCES\.md$/
    }.freeze

    class << self
      # Import a Template from a directory containing spec files.
      #
      # @param path [String] directory containing spec markdown files
      # @param name [String] template name
      # @param repo_url [String] optional repository URL
      # @return [DevExperience::Template]
      def import_template(path:, name:, repo_url: nil)
        template = Template.find_or_initialize_by(name: name)
        template.update!(repo_url: repo_url) if repo_url

        import_specs(path: path, owner: template)
        template
      end

      # Import an App from a directory containing spec files.
      #
      # @param path [String] directory containing spec markdown files
      # @param name [String] app name
      # @param template_name [String] name of the parent Template
      # @param repo_url [String] optional repository URL
      # @return [DevExperience::App]
      def import_app(path:, name:, template_name:, repo_url: nil)
        template = Template.find_by!(name: template_name)
        app = App.find_or_initialize_by(name: name, template: template)
        app.update!(repo_url: repo_url) if repo_url

        import_specs(path: path, owner: app)
        app
      end

      private

      def import_specs(path:, owner:)
        dir = Pathname.new(path)
        return unless dir.directory?

        files = dir.children.select(&:file?)

        actors_file = files.find { |f| f.to_s.match?(SPEC_PATTERNS[:actors]) }
        use_cases_file = files.find { |f| f.to_s.match?(SPEC_PATTERNS[:use_cases]) }
        sequences_file = files.find { |f| f.to_s.match?(SPEC_PATTERNS[:sequences]) }

        parse_actors(actors_file.read, owner: owner) if actors_file
        parse_use_cases(use_cases_file.read, owner: owner) if use_cases_file
        parse_sequences(sequences_file.read, owner: owner) if sequences_file
      end

      # Parses `## N. Name` headings followed by description text.
      def parse_actors(content, owner:)
        content.scan(/^## \d+\.\s+(.+?)\s*(?:\(.*?\))?\s*\n\n(.+?)(?=\n## |\z)/m).each do |name, description|
          Actor.find_or_create_by!(name: name.strip, owner: owner) do |actor|
            actor.description = description.strip
          end
        end
      end

      # Parses `## UC-N: Name` headings with **Implements:** and **Description:** lines.
      def parse_use_cases(content, owner:)
        sections = content.split(/^## /).drop(1)

        sections.each do |section|
          header = section.lines.first&.strip
          next unless header

          match = header.match(/^(UC-\d+):\s+(.+)/)
          next unless match

          identifier = match[1]
          name = match[2].strip

          description = extract_field(section, "Description")
          implements_ref = extract_field(section, "Implements")
          actors_field = extract_field(section, "Actor")

          implements = resolve_implements(implements_ref, owner: owner)

          use_case = UseCase.find_or_initialize_by(identifier: identifier, owner: owner)
          use_case.update!(
            name: name,
            description: description,
            implements: implements
          )

          link_actors(use_case, actors_field, owner: owner) if actors_field
        end
      end

      # Parses `## Sequence N: Name` headings with fenced code blocks containing
      # `Actor -action-> Actor` lines.
      def parse_sequences(content, owner:)
        sections = content.split(/^## /).drop(1)

        sections.each do |section|
          header = section.lines.first&.strip
          next unless header

          seq_name = header.sub(/^Sequence \d+:\s*/, "").strip

          code_blocks = section.scan(/```\n(.+?)```/m)
          next if code_blocks.empty?

          sequence = Sequence.find_or_initialize_by(name: seq_name, owner: owner)
          sequence.save!
          sequence.steps.destroy_all

          position = 0
          code_blocks.each do |block_match|
            block_match[0].each_line do |line|
              line = line.strip.gsub(/^\s+/, "")
              step_match = line.match(/^(\S+)\s+-(\w+)->\s+(.+)/)
              next unless step_match

              from_name = step_match[1]
              action = step_match[2]
              to_raw = step_match[3]

              # Handle parenthetical alternatives: "AI_Agent (or Human_Agent)"
              to_names = to_raw.split(/,\s*|\s+\(or\s+/).map { |n| n.gsub(/[()]/, "").strip }

              to_names.each do |to_name|
                next if to_name.empty?

                from_actor = find_or_create_actor(from_name, owner: owner)
                to_actor = find_or_create_actor(to_name, owner: owner)

                position += 1
                Step.create!(
                  sequence: sequence,
                  position: position,
                  from_actor: from_actor,
                  to_actor: to_actor,
                  action: action
                )
              end
            end
          end
        end
      end

      def extract_field(section, field_name)
        match = section.match(/^\*\*#{field_name}:\*\*\s*(.+)/i)
        match&.[](1)&.strip
      end

      # Resolves "RCOC UC-1 (Authenticate)" to the Template-level UseCase.
      def resolve_implements(ref, owner:)
        return nil unless ref

        match = ref.match(/(UC-\d+)/)
        return nil unless match

        template = case owner
                   when App then owner.template
                   when Template then nil
                   end
        return nil unless template

        UseCase.find_by(identifier: match[1], owner: template)
      end

      def link_actors(use_case, actors_field, owner:)
        actor_names = actors_field.split(/,\s*/)
        actor_names.each do |actor_name|
          actor = find_or_create_actor(actor_name.strip, owner: owner)
          UseCaseActor.find_or_create_by!(use_case: use_case, actor: actor)
        end
      end

      def find_or_create_actor(name, owner:)
        Actor.find_or_create_by!(name: name, owner: owner)
      end
    end
  end
end
