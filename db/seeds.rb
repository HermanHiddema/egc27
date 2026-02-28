# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create or reset test user with properly hashed password
user = User.find_or_initialize_by(email: "test@example.com")
user.update!(
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123",
  full_name: "Test User"
)

puts "✓ Test user created: test@example.com / password123"

static_pages_path = Rails.root.join("db/static_pages.yml")
seeded_pages = 0

if File.exist?(static_pages_path)
  static_pages = YAML.safe_load_file(static_pages_path) || []

  static_pages.each do |page_data|
    next unless page_data.is_a?(Hash)

    slug = page_data["slug"].to_s.strip
    title = page_data["title"].to_s.strip
    content = page_data["content"].to_s.strip

    next if slug.blank? || title.blank? || content.blank?

    page = Page.find_or_initialize_by(slug: slug)
    next if page.persisted? # Skip if page already exists

    page.title = title
    page.content = content
    page.save!

    puts "✓ Page created: #{slug}"
    seeded_pages += 1
  end
end

puts "✓ Seeded #{seeded_pages} static content pages"

header_menu = Menu.find_or_initialize_by(location: "header")
header_menu.name = "Header Navigation"
header_menu.active = true
header_menu.save!

header_menu.menu_items.destroy_all

create_menu_item = lambda do |menu:, label:, position:, parent: nil, page_slug: nil, url: nil, visible: true, open_in_new_tab: false|
  page = page_slug.present? ? Page.find_by!(slug: page_slug) : nil

  menu.menu_items.create!(
    label: label,
    parent: parent,
    page: page,
    url: url,
    position: position,
    visible: visible,
    open_in_new_tab: open_in_new_tab
  )
end

create_menu_item.call(menu: header_menu, label: "Home", position: 1, url: "/")
create_menu_item.call(menu: header_menu, label: "News", position: 2, url: "/articles")
create_menu_item.call(menu: header_menu, label: "Schedule", position: 3, page_slug: "schedule")

go_tournaments = create_menu_item.call(menu: header_menu, label: "Go Tournaments", position: 4, url: "#")
%w[
  egc-rules
  european-championship
  main-open
  weekend-tournament
  pandanet
  rapid
  senior
  youth
  pair-go
  marathon-9x9
  marathon-13x13
  blitz
  women
  teams
  tsume-go
  chess-and-go
  beer-and-go
  torus-go
  hexgo
].each_with_index do |slug, index|
  create_menu_item.call(
    menu: header_menu,
    label: Page.find_by!(slug: slug).title,
    position: index + 1,
    parent: go_tournaments,
    page_slug: slug
  )
end

other_activities = create_menu_item.call(menu: header_menu, label: "Other Activities", position: 5, url: "#")
%w[
  opening-ceremony
  group-photo
  egf-meeting
  conference
  prizegivings
  game-reviews
  simultaneous-games
  lectures
  tsume-go-activity
  poker
  other-games
  sport
].each_with_index do |slug, index|
  create_menu_item.call(
    menu: header_menu,
    label: Page.find_by!(slug: slug).title,
    position: index + 1,
    parent: other_activities,
    page_slug: slug
  )
end

excursions = create_menu_item.call(menu: header_menu, label: "Excursions", position: 13, parent: other_activities, url: "#")
%w[
  excursions-organised-local
  excursions-organised-out-of-town
  excursions-diy-local
  excursions-diy-out-of-town
].each_with_index do |slug, index|
  create_menu_item.call(
    menu: header_menu,
    label: Page.find_by!(slug: slug).title,
    position: index + 1,
    parent: excursions,
    page_slug: slug
  )
end

eat_and_drink = create_menu_item.call(menu: header_menu, label: "Eat and Drink", position: 6, url: "#")
create_menu_item.call(menu: header_menu, label: "Go Coins", position: 1, parent: eat_and_drink, page_slug: "go-coins")

meals = create_menu_item.call(menu: header_menu, label: "Meals", position: 2, parent: eat_and_drink, url: "#")
%w[
  vip-dinner
  bbq-saturday
  onsite-meals
  local-restaurants
  local-bars
].each_with_index do |slug, index|
  create_menu_item.call(
    menu: header_menu,
    label: Page.find_by!(slug: slug).title,
    position: index + 1,
    parent: meals,
    page_slug: slug
  )
end

who_is_here = create_menu_item.call(menu: header_menu, label: "Who is here", position: 7, url: "#")
%w[
  participants
  teachers
  shops
  exhibitors
].each_with_index do |slug, index|
  create_menu_item.call(
    menu: header_menu,
    label: Page.find_by!(slug: slug).title,
    position: index + 1,
    parent: who_is_here,
    page_slug: slug
  )
end

create_menu_item.call(menu: header_menu, label: "Sponsors", position: 8, page_slug: "sponsors")
create_menu_item.call(menu: header_menu, label: "Venue", position: 9, page_slug: "venue")

sleep = create_menu_item.call(menu: header_menu, label: "Sleep", position: 10, url: "#")
%w[
  hotels
  camping
  budget-accommodation
].each_with_index do |slug, index|
  create_menu_item.call(
    menu: header_menu,
    label: Page.find_by!(slug: slug).title,
    position: index + 1,
    parent: sleep,
    page_slug: slug
  )
end

create_menu_item.call(menu: header_menu, label: "Contact", position: 11, page_slug: "contact")

puts "✓ Seeded header menu with #{header_menu.menu_items.count} menu items"
