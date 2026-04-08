Rails.application.routes.draw do
  devise_for :users,
    controllers: {
      sessions: "users/sessions",
      magic_links: "devise/magic_links"
    }

  # Magic-link (passwordless) sign-in: request a link by email
  devise_scope :user do
    get  "users/magic_link/new",  to: "users/magic_links#new",    as: :new_user_magic_link_session
    post "users/magic_link",      to: "users/magic_links#create",  as: :user_magic_link_session
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :articles
  resources :events do
    resources :event_registrations, only: [:new, :create, :destroy]
  end
  get "calendar" => "calendar_events#index", as: :calendar
  resources :calendar_events do
    collection do
      get :day
      get :week
      get :two_weeks
      get :three_weeks
      get :list
    end
  end
  resources :pages, param: :slug
  resources :participants, only: [:index, :new, :create] do
    collection do
      get :egd_search
    end
  end
  resources :menus do
    resources :menu_items
  end

  root "home#index"
end
