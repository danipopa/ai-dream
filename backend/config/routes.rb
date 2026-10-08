Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :memories, only: %i[index show create update destroy] do
        resources :conversation_messages, only: %i[index create], path: :conversation
        resources :video_jobs, only: %i[index create], path: :videos
        resource :voice_profile, only: %i[show create], path: :voice
        resources :speech_generations, only: %i[index create], path: :speech
      end
    end
  end

  get "uploads/:filename" => "uploads#show", as: :uploaded_file, constraints: { filename: /[^\/]+/ }, format: false

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
