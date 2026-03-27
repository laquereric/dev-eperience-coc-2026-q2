# frozen_string_literal: true

class CreateDevExperienceSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_steps do |t|
      t.references :sequence, null: false, foreign_key: { to_table: :dev_experience_sequences }
      t.integer :position, null: false
      t.references :from_actor, null: false, foreign_key: { to_table: :dev_experience_actors }
      t.references :to_actor, null: false, foreign_key: { to_table: :dev_experience_actors }
      t.string :action, null: false

      t.timestamps
    end

    add_index :dev_experience_steps, [:sequence_id, :position], unique: true
  end
end
