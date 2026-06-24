Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users,
    skip: [:registrations],
    controllers: {
      sessions: "users/sessions",
      confirmations: "users/confirmations",
      magic_links: "devise/magic_links"
    }

  # Account management (edit/update/delete) without public self-registration.
  # Public sign-up is intentionally disabled; admins invite users instead.
  devise_scope :user do
    resource :registration,
      only: [:edit, :update, :destroy],
      path: "users",
      path_names: { edit: "edit" },
      controller: "users/registrations",
      as: :user_registration
  end

  # Magic-link (passwordless) sign-in: request a link by email
  devise_scope :user do
    get  "users/magic_link/new",  to: "users/magic_links#new",    as: :new_user_magic_link_session
    post "users/magic_link",      to: "users/magic_links#create",  as: :user_magic_link_session
  end

  # Allow newly confirmed registration users to skip setting a password and go
  # straight to their registrations, relying on magic-link sign-in in future.
  devise_scope :user do
    post "users/skip_password", to: "users/registrations#skip_password", as: :skip_user_password
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
  resources :notices, except: [:show] do
    member do
      patch :deactivate
      patch :reactivate
    end
  end
  get "calendar" => "calendar_events#index", as: :calendar
  get "schedule" => "schedule#index", as: :schedule
  resources :calendar_events do
    collection do
      get :day
      get :week
      get :two_weeks
      get :three_weeks
      get :list
    end
  end
  resources :event_groups, except: [:show]
  resources :pages, param: :slug
  resources :participants, only: [:index, :new, :create, :show] do
    collection do
      get :egd_search
      get :mine
    end
    member do
      get :confirm
    end
    resource :payment, only: [:new, :create], controller: "payments"
  end
  resources :payments, only: [] do
    collection do
      post :webhook
      get :success
    end
  end
  resources :users, only: [:index, :edit, :update]
  get "users/invite", to: "users#invite", as: :invite_user
  post "users/invite", to: "users#send_invitation", as: :send_invitation_user
  get "newsletter", to: "newsletter_subscriptions#new", as: :newsletter
  resources :newsletter_subscriptions, only: [:index, :create, :edit, :update]
  get "newsletter/unsubscribe/:token", to: "newsletter_subscriptions#unsubscribe", as: :unsubscribe_newsletter
  delete "newsletter/unsubscribe/:token", to: "newsletter_subscriptions#destroy", as: :destroy_unsubscribe_newsletter
  resources :menus do
    resources :menu_items
  end

  get "dashboard", to: "dashboard#index", as: :dashboard
  resources :sponsors, except: [:show]

  root "home#index"
end
