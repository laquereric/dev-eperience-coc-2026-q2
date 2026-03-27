# frozen_string_literal: true

module DevExperience
  class Step < ApplicationRecord
    belongs_to :sequence
    belongs_to :from_actor, class_name: "DevExperience::Actor"
    belongs_to :to_actor, class_name: "DevExperience::Actor"

    validates :position, presence: true, uniqueness: { scope: :sequence_id }
    validates :action, presence: true
  end
end
