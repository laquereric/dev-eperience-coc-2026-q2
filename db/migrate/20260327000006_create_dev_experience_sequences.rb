# frozen_string_literal: true

class CreateDevExperienceSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_sequences do |t|
      t.string :name, null: false
      t.references :owner, polymorphic: true, null: false

      t.timestamps
    end

    add_index :dev_experience_sequences, [:name, :owner_type, :owner_id], unique: true,
              name: :idx_dev_experience_sequences_on_name_and_owner
  end
end
