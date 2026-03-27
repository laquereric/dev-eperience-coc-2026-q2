# frozen_string_literal: true

class CreateDevExperienceActors < ActiveRecord::Migration[8.1]
  def change
    create_table :dev_experience_actors do |t|
      t.string :name, null: false
      t.text :description
      t.references :owner, polymorphic: true, null: false

      t.timestamps
    end

    add_index :dev_experience_actors, [:name, :owner_type, :owner_id], unique: true,
              name: :idx_dev_experience_actors_on_name_and_owner
  end
end
