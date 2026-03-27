# frozen_string_literal: true

module DevExperience
  class Actor < ApplicationRecord
    belongs_to :owner, polymorphic: true
    has_many :use_case_actors, dependent: :destroy
    has_many :use_cases, through: :use_case_actors

    validates :name, presence: true, uniqueness: { scope: [:owner_type, :owner_id] }
  end
end
