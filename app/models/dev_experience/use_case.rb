# frozen_string_literal: true

module DevExperience
  class UseCase < ApplicationRecord
    belongs_to :owner, polymorphic: true
    belongs_to :implements, class_name: "DevExperience::UseCase", optional: true
    has_many :use_case_actors, dependent: :destroy
    has_many :actors, through: :use_case_actors

    validates :identifier, presence: true, uniqueness: { scope: [:owner_type, :owner_id] }
    validates :name, presence: true
  end
end
