# frozen_string_literal: true

class CreateDevExperienceUseCaseActors < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_use_case_actors do |t|
      t.references :use_case, null: false, foreign_key: { to_table: :dev_experience_use_cases }
      t.references :actor, null: false, foreign_key: { to_table: :dev_experience_actors }

      t.timestamps
    end

    add_index :dev_experience_use_case_actors, [:use_case_id, :actor_id], unique: true,
              name: :idx_dev_experience_use_case_actors_uniqueness
  end
end
