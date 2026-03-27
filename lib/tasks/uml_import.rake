# frozen_string_literal: true

namespace :dev_experience do
  desc "Import all UML specs from vendor/ templates and apps/ directories into the database"
  task import: :environment do
    require "dev_experience/uml_import"

    base = find_project_root

    # Import templates from vendor/ directories that have spec files
    vendor_dir = base.join("vendor")
    if vendor_dir.directory?
      vendor_dir.children.select(&:directory?).each do |dir|
        files = dir.children.select(&:file?).map(&:basename).map(&:to_s)
        has_specs = files.any? { |f| f.match?(/(?:\w+_)?(?:ACTORS|USE_CASES|SEQUENCES)\.md$/) }
        next unless has_specs

        name = dir.basename.to_s
        puts "Importing template: #{name}"
        DevExperience::UmlImport.import_template(path: dir.to_s, name: name)
      end
    end

    # Import apps from apps/ directories that have spec files
    apps_dir = base.join("apps")
    if apps_dir.directory?
      apps_dir.children.select(&:directory?).each do |dir|
        files = dir.children.select(&:file?).map(&:basename).map(&:to_s)
        has_specs = files.any? { |f| f.match?(/(?:\w+_)?(?:ACTORS|USE_CASES|SEQUENCES)\.md$/) }
        next unless has_specs

        name = dir.basename.to_s
        template_name = infer_template_name(name)
        next unless template_name

        puts "Importing app: #{name} (template: #{template_name})"
        DevExperience::UmlImport.import_app(path: dir.to_s, name: name, template_name: template_name)
      end
    end

    puts "Done."
  end

  desc "Import a single template"
  task :import_template, [:path, :name] => :environment do |_t, args|
    require "dev_experience/uml_import"
    DevExperience::UmlImport.import_template(path: args[:path], name: args[:name])
    puts "Imported template: #{args[:name]}"
  end

  desc "Import a single app"
  task :import_app, [:path, :name, :template_name] => :environment do |_t, args|
    require "dev_experience/uml_import"
    DevExperience::UmlImport.import_app(
      path: args[:path],
      name: args[:name],
      template_name: args[:template_name]
    )
    puts "Imported app: #{args[:name]}"
  end
end

# Walk up from Rails.root to find the project root (directory containing both vendor/ and apps/).
def find_project_root
  dir = Pathname.new(Rails.root)
  5.times do
    return dir if dir.join("vendor").directory? && dir.join("apps").directory?
    dir = dir.parent
  end
  # Fallback: assume one level up from Rails.root
  Pathname.new(Rails.root).join("..")
end

def infer_template_name(app_name)
  case app_name
  when /^rcoc-/ then "rails-coc-2026-q2"
  end
end
