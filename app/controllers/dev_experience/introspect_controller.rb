# frozen_string_literal: true

module DevExperience
  class IntrospectController < ApplicationController
    skip_forgery_protection

    def create
      bank_id = params.require(:bank_id)
      query = params.require(:query)

      result = Hindsight.client.memories.recall(bank_id, query, budget: "mid")
      render json: result
    rescue Hindsight::Error => e
      render json: { error: e.message }, status: :service_unavailable
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
