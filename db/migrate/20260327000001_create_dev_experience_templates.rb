# frozen_string_literal: true

class CreateDevExperienceTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_templates do |t|
      t.string :name, null: false
      t.text :description
      t.string :repo_url

      t.timestamps
    end

    add_index :dev_experience_templates, :name, unique: true
  end
end
