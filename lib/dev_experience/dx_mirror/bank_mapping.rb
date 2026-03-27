# frozen_string_literal: true

module DevExperience
  module DxMirror
    module BankMapping
      class << self
        def banks_for(controller_key:, model_names:)
          mapping = DxMirror.configuration.bank_mapping
          banks = []

          banks += Array(mapping[controller_key])
          model_names.each { |name| banks += Array(mapping[name]) }

          app_name = Rails.application.class.module_parent_name.underscore.dasherize
          banks << "dx:app:#{app_name}"

          banks.uniq
        end
      end
    end
  end
end
