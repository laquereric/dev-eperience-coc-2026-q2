# frozen_string_literal: true

DevExperience::Engine.routes.draw do
  resources :templates, only: [:index, :show] do
    member do
      get :actors
      get :use_cases
      get :sequences
    end
  end

  resources :apps, only: [:index, :show] do
    member do
      get :actors
      get :use_cases
      get :sequences
    end
  end

  root to: "templates#index"
end
