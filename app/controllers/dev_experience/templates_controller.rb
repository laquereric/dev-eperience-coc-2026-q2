# frozen_string_literal: true

module DevExperience
  class TemplatesController < ApplicationController
    def index
      @templates = Template.all
    end

    def show
      @template = Template.find(params[:id])
    end

    def actors
      @template = Template.find(params[:id])
      @actors = @template.actors
    end

    def use_cases
      @template = Template.find(params[:id])
      @use_cases = @template.use_cases.includes(:actors, :implements)
    end

    def sequences
      @template = Template.find(params[:id])
      @sequences = @template.sequences.includes(steps: [:from_actor, :to_actor])
    end
  end
end
