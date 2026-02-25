Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "style-guide" => "home#style_guide", as: :style_guide
  get "debug" => "home#debug", as: :debug

  # Static pages for menu
  get "about" => "pages#about", as: :about
  get "schedule" => "pages#schedule", as: :schedule
  get "venue" => "pages#venue", as: :venue
  get "contact" => "pages#contact", as: :contact

  # Go Tournaments
  get "go-tournaments/egc-rules" => "pages#egc_rules", as: :egc_rules
  get "go-tournaments/european-championship" => "pages#european_championship", as: :european_championship
  get "go-tournaments/main-open" => "pages#main_open", as: :main_open
  get "go-tournaments/weekend" => "pages#weekend_tournament", as: :weekend_tournament
  get "go-tournaments/pandanet" => "pages#pandanet", as: :pandanet
  get "go-tournaments/rapid" => "pages#rapid", as: :rapid
  get "go-tournaments/senior" => "pages#senior", as: :senior
  get "go-tournaments/youth" => "pages#youth", as: :youth
  get "go-tournaments/pair-go" => "pages#pair_go", as: :pair_go
  get "go-tournaments/marathon-9x9" => "pages#marathon_9x9", as: :marathon_9x9
  get "go-tournaments/marathon-13x13" => "pages#marathon_13x13", as: :marathon_13x13
  get "go-tournaments/blitz" => "pages#blitz", as: :blitz
  get "go-tournaments/women" => "pages#women", as: :women
  get "go-tournaments/teams" => "pages#teams", as: :teams
  get "go-tournaments/tsume-go" => "pages#tsume_go", as: :tsume_go
  get "go-tournaments/chess-and-go" => "pages#chess_and_go", as: :chess_and_go
  get "go-tournaments/beer-and-go" => "pages#beer_and_go", as: :beer_and_go
  get "go-tournaments/torus-go" => "pages#torus_go", as: :torus_go
  get "go-tournaments/hexgo" => "pages#hexgo", as: :hexgo

  # Other Activities
  get "activities/opening-ceremony" => "pages#opening_ceremony", as: :opening_ceremony
  get "activities/group-photo" => "pages#group_photo", as: :group_photo
  get "activities/egf-meeting" => "pages#egf_meeting", as: :egf_meeting
  get "activities/conference" => "pages#conference", as: :conference
  get "activities/prizegivings" => "pages#prizegivings", as: :prizegivings
  get "activities/game-reviews" => "pages#game_reviews", as: :game_reviews
  get "activities/simultaneous-games" => "pages#simultaneous_games", as: :simultaneous_games
  get "activities/lectures" => "pages#lectures", as: :lectures
  get "activities/tsume-go-activity" => "pages#tsume_go_activity", as: :tsume_go_activity
  get "activities/poker" => "pages#poker", as: :poker
  get "activities/other-games" => "pages#other_games", as: :other_games
  get "activities/sport" => "pages#sport", as: :sport
  get "activities/excursions/organised-local" => "pages#excursions_organised_local", as: :excursions_organised_local
  get "activities/excursions/organised-out-of-town" => "pages#excursions_organised_out_of_town", as: :excursions_organised_out_of_town
  get "activities/excursions/diy-local" => "pages#excursions_diy_local", as: :excursions_diy_local
  get "activities/excursions/diy-out-of-town" => "pages#excursions_diy_out_of_town", as: :excursions_diy_out_of_town

  # Eat and Drink
  get "eat-and-drink/go-coins" => "pages#go_coins", as: :go_coins
  get "eat-and-drink/meals/vip-dinner" => "pages#vip_dinner", as: :vip_dinner
  get "eat-and-drink/meals/bbq-saturday" => "pages#bbq_saturday", as: :bbq_saturday
  get "eat-and-drink/meals/onsite-meals" => "pages#onsite_meals", as: :onsite_meals
  get "eat-and-drink/meals/local-restaurants" => "pages#local_restaurants", as: :local_restaurants
  get "eat-and-drink/meals/local-bars" => "pages#local_bars", as: :local_bars

  # Sleep
  get "sleep/hotels" => "pages#hotels", as: :hotels
  get "sleep/camping" => "pages#camping", as: :camping
  get "sleep/budget" => "pages#budget_accommodation", as: :budget_accommodation

  # Who is here
  get "who-is-here/participants" => "pages#participants", as: :participants
  get "who-is-here/teachers" => "pages#teachers", as: :teachers
  get "who-is-here/shops" => "pages#shops", as: :shops
  get "who-is-here/exhibitors" => "pages#exhibitors", as: :exhibitors

  devise_scope :user do
    authenticated :user do
      root "home#index", as: :authenticated_root
    end

    unauthenticated do
      root "devise/sessions#new", as: :unauthenticated_root
    end
  end

  root "home#index"
end
