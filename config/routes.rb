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

  resources :articles

  # Static pages for menu
  get "about" => "static_content#about", as: :about
  get "schedule" => "static_content#schedule", as: :schedule
  get "venue" => "static_content#venue", as: :venue
  get "contact" => "static_content#contact", as: :contact

  # Go Tournaments
  get "go-tournaments/egc-rules" => "static_content#egc_rules", as: :egc_rules
  get "go-tournaments/european-championship" => "static_content#european_championship", as: :european_championship
  get "go-tournaments/main-open" => "static_content#main_open", as: :main_open
  get "go-tournaments/weekend" => "static_content#weekend_tournament", as: :weekend_tournament
  get "go-tournaments/pandanet" => "static_content#pandanet", as: :pandanet
  get "go-tournaments/rapid" => "static_content#rapid", as: :rapid
  get "go-tournaments/senior" => "static_content#senior", as: :senior
  get "go-tournaments/youth" => "static_content#youth", as: :youth
  get "go-tournaments/pair-go" => "static_content#pair_go", as: :pair_go
  get "go-tournaments/marathon-9x9" => "static_content#marathon_9x9", as: :marathon_9x9
  get "go-tournaments/marathon-13x13" => "static_content#marathon_13x13", as: :marathon_13x13
  get "go-tournaments/blitz" => "static_content#blitz", as: :blitz
  get "go-tournaments/women" => "static_content#women", as: :women
  get "go-tournaments/teams" => "static_content#teams", as: :teams
  get "go-tournaments/tsume-go" => "static_content#tsume_go", as: :tsume_go
  get "go-tournaments/chess-and-go" => "static_content#chess_and_go", as: :chess_and_go
  get "go-tournaments/beer-and-go" => "static_content#beer_and_go", as: :beer_and_go
  get "go-tournaments/torus-go" => "static_content#torus_go", as: :torus_go
  get "go-tournaments/hexgo" => "static_content#hexgo", as: :hexgo

  # Other Activities
  get "activities/opening-ceremony" => "static_content#opening_ceremony", as: :opening_ceremony
  get "activities/group-photo" => "static_content#group_photo", as: :group_photo
  get "activities/egf-meeting" => "static_content#egf_meeting", as: :egf_meeting
  get "activities/conference" => "static_content#conference", as: :conference
  get "activities/prizegivings" => "static_content#prizegivings", as: :prizegivings
  get "activities/game-reviews" => "static_content#game_reviews", as: :game_reviews
  get "activities/simultaneous-games" => "static_content#simultaneous_games", as: :simultaneous_games
  get "activities/lectures" => "static_content#lectures", as: :lectures
  get "activities/tsume-go-activity" => "static_content#tsume_go_activity", as: :tsume_go_activity
  get "activities/poker" => "static_content#poker", as: :poker
  get "activities/other-games" => "static_content#other_games", as: :other_games
  get "activities/sport" => "static_content#sport", as: :sport
  get "activities/excursions/organised-local" => "static_content#excursions_organised_local", as: :excursions_organised_local
  get "activities/excursions/organised-out-of-town" => "static_content#excursions_organised_out_of_town", as: :excursions_organised_out_of_town
  get "activities/excursions/diy-local" => "static_content#excursions_diy_local", as: :excursions_diy_local
  get "activities/excursions/diy-out-of-town" => "static_content#excursions_diy_out_of_town", as: :excursions_diy_out_of_town

  # Eat and Drink
  get "eat-and-drink/go-coins" => "static_content#go_coins", as: :go_coins
  get "eat-and-drink/meals/vip-dinner" => "static_content#vip_dinner", as: :vip_dinner
  get "eat-and-drink/meals/bbq-saturday" => "static_content#bbq_saturday", as: :bbq_saturday
  get "eat-and-drink/meals/onsite-meals" => "static_content#onsite_meals", as: :onsite_meals
  get "eat-and-drink/meals/local-restaurants" => "static_content#local_restaurants", as: :local_restaurants
  get "eat-and-drink/meals/local-bars" => "static_content#local_bars", as: :local_bars

  # Sleep
  get "sleep/hotels" => "static_content#hotels", as: :hotels
  get "sleep/camping" => "static_content#camping", as: :camping
  get "sleep/budget" => "static_content#budget_accommodation", as: :budget_accommodation

  # Who is here
  get "who-is-here/participants" => "static_content#participants", as: :participants
  get "who-is-here/teachers" => "static_content#teachers", as: :teachers
  get "who-is-here/shops" => "static_content#shops", as: :shops
  get "who-is-here/exhibitors" => "static_content#exhibitors", as: :exhibitors

  root "home#index"
end
