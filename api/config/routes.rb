Rails.application.routes.draw do
  get "health", to: "api/v1/health#show"

  namespace :api do
    namespace :v1 do
      resources :exercises, only: %i[index show create update]
      resources :workout_templates, only: %i[index show create update]
      resources :workout_template_exercise_options, only: %i[create]
      resources :workout_sessions, only: %i[index create show update]
      resources :workout_session_exercises, only: %i[update]
      resources :workout_session_sets, only: %i[update]
      get "health", to: "health#show"
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
