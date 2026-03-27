# frozen_string_literal: true

class CreateDevExperienceUseCases < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_use_cases do |t|
      t.string :identifier, null: false
      t.string :name, null: false
      t.text :description
      t.references :owner, polymorphic: true, null: false
      t.references :implements, foreign_key: { to_table: :dev_experience_use_cases }

      t.timestamps
    end

    add_index :dev_experience_use_cases, [:identifier, :owner_type, :owner_id], unique: true,
              name: :idx_dev_experience_use_cases_on_identifier_and_owner
  end
end
