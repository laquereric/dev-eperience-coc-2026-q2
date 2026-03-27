# frozen_string_literal: true

module DevExperience
  class App < ApplicationRecord
    belongs_to :template
    has_many :actors, as: :owner, dependent: :destroy
    has_many :use_cases, as: :owner, dependent: :destroy
    has_many :sequences, as: :owner, dependent: :destroy

    validates :name, presence: true, uniqueness: true
  end
end
