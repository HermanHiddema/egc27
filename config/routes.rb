Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users,
    skip: [:registrations],
    controllers: {
      sessions: "users/sessions",
      confirmations: "users/confirmations",
      passwords: "users/passwords",
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

  # Active Storage routes are drawn here instead of by the engine
  # (config.active_storage.draw_routes is false) so that the unauthenticated
  # POST /rails/active_storage/direct_uploads endpoint, which this application
  # does not use, does not exist. Everything else mirrors the engine defaults.
  scope ActiveStorage.routes_prefix do
    get "/blobs/redirect/:signed_id/*filename" => "active_storage/blobs/redirect#show", as: :rails_service_blob
    get "/blobs/proxy/:signed_id/*filename" => "active_storage/blobs/proxy#show", as: :rails_service_blob_proxy
    get "/blobs/:signed_id/*filename" => "active_storage/blobs/redirect#show"

    get "/representations/redirect/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/redirect#show", as: :rails_blob_representation
    get "/representations/proxy/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/proxy#show", as: :rails_blob_representation_proxy
    get "/representations/:signed_blob_id/:variation_key/*filename" => "active_storage/representations/redirect#show"

    get "/disk/:encoded_key/*filename" => "active_storage/disk#show", as: :rails_disk_service
    put "/disk/:encoded_token" => "active_storage/disk#update", as: :update_rails_disk_service
  end

  direct :rails_representation do |representation, options|
    route_for(ActiveStorage.resolve_model_to_route, representation, options)
  end

  resolve("ActiveStorage::Variant") { |variant, options| route_for(ActiveStorage.resolve_model_to_route, variant, options) }
  resolve("ActiveStorage::VariantWithRecord") { |variant, options| route_for(ActiveStorage.resolve_model_to_route, variant, options) }
  resolve("ActiveStorage::Preview") { |preview, options| route_for(ActiveStorage.resolve_model_to_route, preview, options) }

  direct :rails_blob do |blob, options|
    route_for(ActiveStorage.resolve_model_to_route, blob, options)
  end

  resolve("ActiveStorage::Blob")       { |blob, options| route_for(ActiveStorage.resolve_model_to_route, blob, options) }
  resolve("ActiveStorage::Attachment") { |attachment, options| route_for(ActiveStorage.resolve_model_to_route, attachment.blob, options) }

  direct :rails_storage_proxy do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }
    expires_at = options.delete(:expires_at)

    if model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob_proxy,
        model.signed_id(expires_in: expires_in, expires_at: expires_at),
        model.filename,
        options
      )
    else
      route_for(
        :rails_blob_representation_proxy,
        model.blob.signed_id(expires_in: expires_in, expires_at: expires_at),
        model.variation.key,
        model.blob.filename,
        options
      )
    end
  end

  direct :rails_storage_redirect do |model, options|
    expires_in = options.delete(:expires_in) { ActiveStorage.urls_expire_in }
    expires_at = options.delete(:expires_at)

    if model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob,
        model.signed_id(expires_in: expires_in, expires_at: expires_at),
        model.filename,
        options
      )
    else
      route_for(
        :rails_blob_representation,
        model.blob.signed_id(expires_in: expires_in, expires_at: expires_at),
        model.variation.key,
        model.blob.filename,
        options
      )
    end
  end

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
      get :egd_registered
      post :email_registered
      get :alter_registration
      get :mine
    end
    member do
      get :confirm
      post :resend_confirmation
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

  get "search", to: "search#index", as: :search

  namespace :tinymce do
    resources :images, only: [:create]
  end

  get "dashboard", to: "dashboard#index", as: :dashboard
  resources :sponsors, except: [:show]

  namespace :admin do
    resources :participants, only: [:index, :edit, :update, :destroy] do
      resources :payments, only: [:new, :create, :edit, :update]
    end
    resources :payments, only: [:index] do
      member do
        patch :mark_processed
        patch :unmark_processed
      end
    end
  end

  # Flyers were printed with URLs missing the /pages prefix, so keep those
  # shortcuts working by redirecting them to the real page URLs.
  %w[cns cnt jp kr].each do |slug|
    get slug, to: redirect("/pages/#{slug}")
  end

  root "home#index"
end
