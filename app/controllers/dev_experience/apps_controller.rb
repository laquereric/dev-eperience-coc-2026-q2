# frozen_string_literal: true

module DevExperience
  class AppsController < ApplicationController
    def index
      @apps = App.includes(:template).all
    end

    def show
      @app = App.find(params[:id])
    end

    def actors
      @app = App.find(params[:id])
      @actors = @app.actors
    end

    def use_cases
      @app = App.find(params[:id])
      @use_cases = @app.use_cases.includes(:actors, :implements)
    end

    def sequences
      @app = App.find(params[:id])
      @sequences = @app.sequences.includes(steps: [:from_actor, :to_actor])
    end
  end
end
