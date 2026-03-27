# frozen_string_literal: true

module DevExperience
  class UseCaseActor < ApplicationRecord
    belongs_to :use_case
    belongs_to :actor

    validates :actor_id, uniqueness: { scope: :use_case_id }
  end
end
