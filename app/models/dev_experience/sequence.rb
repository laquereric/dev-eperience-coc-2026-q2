# frozen_string_literal: true

module DevExperience
  class Sequence < ApplicationRecord
    belongs_to :owner, polymorphic: true
    has_many :steps, -> { order(:position) }, dependent: :destroy

    validates :name, presence: true, uniqueness: { scope: [:owner_type, :owner_id] }
  end
end
