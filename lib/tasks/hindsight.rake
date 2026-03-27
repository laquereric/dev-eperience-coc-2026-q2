# frozen_string_literal: true

namespace :hindsight do
  desc "Sync all UML specs (templates and apps) to Hindsight memory banks"
  task sync: :environment do
    require "dev_experience/uml_sync"

    client = Hindsight.client
    root = Rails.root

    # Sync templates from vendor/
    sync_templates(root, client)

    # Sync apps from apps/
    sync_apps(root, client)

    puts "\nDone."
  end

  desc "Sync a single template: hindsight:sync_template[path,name]"
  task :sync_template, [:path, :name] => :environment do |_t, args|
    require "dev_experience/uml_sync"

    DevExperience::UmlSync.sync_template(
      path: args[:path],
      name: args[:name],
      client: Hindsight.client
    )
  end

  desc "Sync a single app: hindsight:sync_app[path,name,template_name]"
  task :sync_app, [:path, :name, :template_name] => :environment do |_t, args|
    require "dev_experience/uml_sync"

    DevExperience::UmlSync.sync_app(
      path: args[:path],
      name: args[:name],
      template_name: args[:template_name],
      client: Hindsight.client
    )
  end
end

def sync_templates(root, client)
  vendor = root.join("vendor")
  return unless vendor.directory?

  vendor.children.select(&:directory?).each do |dir|
    specs = Dir.glob(dir.join("*{ACTORS,USE_CASES,SEQUENCES}.md"))
    next if specs.empty?

    name = dir.basename.to_s
    DevExperience::UmlSync.sync_template(path: dir.to_s, name: name, client: client)
  end
end

def sync_apps(root, client)
  apps_dir = root.join("apps")
  return unless apps_dir.directory?

  apps_dir.children.select(&:directory?).each do |dir|
    specs = Dir.glob(dir.join("*{ACTORS,USE_CASES,SEQUENCES}.md"))
    next if specs.empty?

    name = dir.basename.to_s
    # Infer template from directory name prefix (e.g. rcoc-human-customer -> rails-coc-2026-q2)
    template_name = infer_template(name)
    DevExperience::UmlSync.sync_app(path: dir.to_s, name: name, template_name: template_name, client: client)
  end
end

def infer_template(app_name)
  case app_name
  when /^rcoc-/
    "rails-coc-2026-q2"
  end
end
