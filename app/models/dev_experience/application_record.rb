# frozen_string_literal: true

module DevExperience
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
