# frozen_string_literal: true

class CreateDevExperienceApps < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_apps do |t|
      t.string :name, null: false
      t.references :template, null: false, foreign_key: { to_table: :dev_experience_templates }
      t.string :repo_url

      t.timestamps
    end

    add_index :dev_experience_apps, :name, unique: true
  end
end
