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

legal_pages = [
  { slug: "privacy", title: "Privacy", content: "This is a placeholder Privacy page. Content coming soon." },
  { slug: "terms-and-conditions", title: "Terms and conditions", content: "This is a placeholder Terms and conditions page. Content coming soon." },
  { slug: "copyright", title: "Copyright", content: "This is a placeholder Copyright page. Content coming soon." },
  { slug: "faq", title: "FAQ", content: "This is a placeholder FAQ page. Content coming soon." }
]

legal_pages.each do |legal_page|
  page = Page.find_or_initialize_by(slug: legal_page[:slug])
  next if page.persisted?

  page.title = legal_page[:title]
  page.content = legal_page[:content]
  page.save!
  puts "✓ Page created: #{legal_page[:slug]}"
end

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
create_menu_item.call(menu: header_menu, label: "Schedule", position: 3, url: "/calendar_events/three_weeks?date=2027-07-19")

go_tournaments = create_menu_item.call(menu: header_menu, label: "Go Tournaments", position: 5, url: "#")
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

other_activities = create_menu_item.call(menu: header_menu, label: "Other Activities", position: 6, url: "#")
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

eat_and_drink = create_menu_item.call(menu: header_menu, label: "Eat and Drink", position: 7, url: "#")
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

who_is_here = create_menu_item.call(menu: header_menu, label: "Who is here", position: 8, url: "#")
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

create_menu_item.call(menu: header_menu, label: "Sponsors", position: 9, page_slug: "sponsors")
create_menu_item.call(menu: header_menu, label: "Venue", position: 10, page_slug: "venue")

sleep = create_menu_item.call(menu: header_menu, label: "Sleep", position: 11, url: "#")
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

create_menu_item.call(menu: header_menu, label: "Contact", position: 12, page_slug: "contact")

puts "✓ Seeded header menu with #{header_menu.menu_items.count} menu items"

footer_menu = Menu.find_or_initialize_by(location: "footer")
footer_menu.name = "Footer Menu"
footer_menu.active = true
footer_menu.save!

footer_menu.menu_items.destroy_all

[
  ["Privacy", "privacy"],
  ["Terms and conditions", "terms-and-conditions"],
  ["Copyright", "copyright"],
  ["FAQ", "faq"],
  ["Contact", "contact"]
].each_with_index do |(label, slug), index|
  create_menu_item.call(
    menu: footer_menu,
    label: label,
    position: index + 1,
    page_slug: slug
  )
end

puts "✓ Seeded footer menu with #{footer_menu.menu_items.count} menu items"

calendar_event_seeds = [
  # Saturday 24th July
  { title: "Registration", starts_at: Time.zone.parse("2027-07-24 10:00"), ends_at: Time.zone.parse("2027-07-24 17:00"), color: "#b7b7b7" },
  { title: "Opening Ceremony", starts_at: Time.zone.parse("2027-07-24 17:00"), ends_at: Time.zone.parse("2027-07-24 18:30"), color: "#ffd966" },
  { title: "Registration", starts_at: Time.zone.parse("2027-07-24 18:30"), ends_at: Time.zone.parse("2027-07-24 22:00"), color: "#b7b7b7" },
  # Sunday 25th July
  { title: "Registration", starts_at: Time.zone.parse("2027-07-25 09:00"), ends_at: Time.zone.parse("2027-07-25 10:00"), color: "#b7b7b7" },
  { title: "Main Open R1", starts_at: Time.zone.parse("2027-07-25 11:00"), ends_at: Time.zone.parse("2027-07-25 15:30"), color: "#c9daf8" },
  { title: "European Championship R1", starts_at: Time.zone.parse("2027-07-25 11:00"), ends_at: Time.zone.parse("2027-07-25 17:00"), color: "#d5a6bd" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-07-25 13:00"), ends_at: Time.zone.parse("2027-07-25 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-25 14:30"), ends_at: Time.zone.parse("2027-07-25 15:30"), color: "#fff2cc" },
  { title: "Rapid R1", starts_at: Time.zone.parse("2027-07-25 16:00"), ends_at: Time.zone.parse("2027-07-25 17:30"), color: "#00ffff" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-25 16:00"), ends_at: Time.zone.parse("2027-07-25 17:00"), color: "#fff2cc" },
  { title: "Senior Tmt R1", starts_at: Time.zone.parse("2027-07-25 17:30"), ends_at: Time.zone.parse("2027-07-25 19:00"), color: "#f4cccc" },
  { title: "VIP Dinner", starts_at: Time.zone.parse("2027-07-25 18:00"), ends_at: Time.zone.parse("2027-07-25 22:00"), color: "#ffd966" },
  { title: "Senior Tmt R2", starts_at: Time.zone.parse("2027-07-25 20:00"), ends_at: Time.zone.parse("2027-07-25 21:30"), color: "#f4cccc" },
  # Monday 26th July
  { title: "Main Open R2", starts_at: Time.zone.parse("2027-07-26 10:00"), ends_at: Time.zone.parse("2027-07-26 14:30"), color: "#c9daf8" },
  { title: "European Championship R2", starts_at: Time.zone.parse("2027-07-26 10:00"), ends_at: Time.zone.parse("2027-07-26 16:00"), color: "#d5a6bd" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-07-26 12:00"), ends_at: Time.zone.parse("2027-07-26 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-26 13:30"), ends_at: Time.zone.parse("2027-07-26 14:30"), color: "#fff2cc" },
  { title: "Fun go*", starts_at: Time.zone.parse("2027-07-26 15:00"), ends_at: Time.zone.parse("2027-07-26 17:30"), color: "#e06666" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-26 15:00"), ends_at: Time.zone.parse("2027-07-26 16:00"), color: "#fff2cc" },
  { title: "Rapid R2", starts_at: Time.zone.parse("2027-07-26 16:00"), ends_at: Time.zone.parse("2027-07-26 17:30"), color: "#00ffff" },
  { title: "Senior Tmt R3", starts_at: Time.zone.parse("2027-07-26 17:30"), ends_at: Time.zone.parse("2027-07-26 19:00"), color: "#f4cccc" },
  { title: "EGF Annual General Meeting", starts_at: Time.zone.parse("2027-07-26 18:00"), ends_at: Time.zone.parse("2027-07-26 23:00"), color: "#ffd966" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-07-26 18:00"), ends_at: Time.zone.parse("2027-07-26 20:00"), color: "#b6d7a8" },
  { title: "Senior Tmt R4", starts_at: Time.zone.parse("2027-07-26 20:00"), ends_at: Time.zone.parse("2027-07-26 21:30"), color: "#f4cccc" },
  # Tuesday 27th July
  { title: "Main Open R3", starts_at: Time.zone.parse("2027-07-27 10:00"), ends_at: Time.zone.parse("2027-07-27 14:30"), color: "#c9daf8" },
  { title: "European Championship R3", starts_at: Time.zone.parse("2027-07-27 10:00"), ends_at: Time.zone.parse("2027-07-27 16:00"), color: "#d5a6bd" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-07-27 12:00"), ends_at: Time.zone.parse("2027-07-27 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-27 13:30"), ends_at: Time.zone.parse("2027-07-27 14:30"), color: "#fff2cc" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-27 15:00"), ends_at: Time.zone.parse("2027-07-27 16:00"), color: "#fff2cc" },
  { title: "Rapid R3", starts_at: Time.zone.parse("2027-07-27 16:00"), ends_at: Time.zone.parse("2027-07-27 17:30"), color: "#00ffff" },
  { title: "Blitz", starts_at: Time.zone.parse("2027-07-27 16:00"), ends_at: Time.zone.parse("2027-07-27 23:00"), color: "#f4cccc" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-07-27 18:00"), ends_at: Time.zone.parse("2027-07-27 20:00"), color: "#b6d7a8" },
  { title: "Joanna Koike", starts_at: Time.zone.parse("2027-07-27 20:00"), ends_at: Time.zone.parse("2027-07-27 21:30"), color: "#6fa8dc" },
  # Wednesday 28th July
  { title: "European Championship R4", starts_at: Time.zone.parse("2027-07-28 10:00"), ends_at: Time.zone.parse("2027-07-28 16:00"), color: "#d5a6bd" },
  { title: "Women tmt R1", starts_at: Time.zone.parse("2027-07-28 10:00"), ends_at: Time.zone.parse("2027-07-28 12:00"), color: "#f4cccc" },
  { title: "Excursions", starts_at: Time.zone.parse("2027-07-28 10:00"), ends_at: Time.zone.parse("2027-07-28 20:00"), color: "#6fa8dc" },
  { title: "Women tmt R2", starts_at: Time.zone.parse("2027-07-28 12:30"), ends_at: Time.zone.parse("2027-07-28 14:30"), color: "#f4cccc" },
  { title: "Women tmt R3", starts_at: Time.zone.parse("2027-07-28 15:00"), ends_at: Time.zone.parse("2027-07-28 17:00"), color: "#f4cccc" },
  { title: "Women tmt R4", starts_at: Time.zone.parse("2027-07-28 18:00"), ends_at: Time.zone.parse("2027-07-28 20:00"), color: "#f4cccc" },
  # Thursday 29th July
  { title: "Main Open R4", starts_at: Time.zone.parse("2027-07-29 10:00"), ends_at: Time.zone.parse("2027-07-29 14:30"), color: "#c9daf8" },
  { title: "European Championship R5", starts_at: Time.zone.parse("2027-07-29 10:00"), ends_at: Time.zone.parse("2027-07-29 16:00"), color: "#d5a6bd" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-07-29 12:00"), ends_at: Time.zone.parse("2027-07-29 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-29 13:30"), ends_at: Time.zone.parse("2027-07-29 14:30"), color: "#fff2cc" },
  { title: "Fun go*", starts_at: Time.zone.parse("2027-07-29 15:00"), ends_at: Time.zone.parse("2027-07-29 17:30"), color: "#e06666" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-29 15:00"), ends_at: Time.zone.parse("2027-07-29 16:00"), color: "#fff2cc" },
  { title: "Rapid R4", starts_at: Time.zone.parse("2027-07-29 16:00"), ends_at: Time.zone.parse("2027-07-29 17:30"), color: "#00ffff" },
  { title: "Team Tmt R1", starts_at: Time.zone.parse("2027-07-29 17:30"), ends_at: Time.zone.parse("2027-07-29 19:00"), color: "#f4cccc" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-07-29 18:00"), ends_at: Time.zone.parse("2027-07-29 20:00"), color: "#b6d7a8" },
  { title: "Team Tmt R2", starts_at: Time.zone.parse("2027-07-29 20:00"), ends_at: Time.zone.parse("2027-07-29 21:30"), color: "#f4cccc" },
  # Friday 30th July
  { title: "Main Open R5", starts_at: Time.zone.parse("2027-07-30 10:00"), ends_at: Time.zone.parse("2027-07-30 14:30"), color: "#c9daf8" },
  { title: "European Championship R6", starts_at: Time.zone.parse("2027-07-30 10:00"), ends_at: Time.zone.parse("2027-07-30 16:00"), color: "#d5a6bd" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-07-30 12:00"), ends_at: Time.zone.parse("2027-07-30 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-30 13:30"), ends_at: Time.zone.parse("2027-07-30 14:30"), color: "#fff2cc" },
  { title: "Fun go*", starts_at: Time.zone.parse("2027-07-30 15:00"), ends_at: Time.zone.parse("2027-07-30 17:30"), color: "#e06666" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-07-30 15:00"), ends_at: Time.zone.parse("2027-07-30 16:00"), color: "#fff2cc" },
  { title: "Rapid R5", starts_at: Time.zone.parse("2027-07-30 16:00"), ends_at: Time.zone.parse("2027-07-30 17:30"), color: "#00ffff" },
  { title: "Team Tmt R3", starts_at: Time.zone.parse("2027-07-30 17:30"), ends_at: Time.zone.parse("2027-07-30 19:00"), color: "#f4cccc" },
  { title: "Registration weekend Tmt", starts_at: Time.zone.parse("2027-07-30 18:00"), ends_at: Time.zone.parse("2027-07-30 22:00"), color: "#b7b7b7" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-07-30 18:00"), ends_at: Time.zone.parse("2027-07-30 20:00"), color: "#b6d7a8" },
  { title: "Team Tmt R4", starts_at: Time.zone.parse("2027-07-30 20:00"), ends_at: Time.zone.parse("2027-07-30 21:30"), color: "#f4cccc" },
  # Saturday 31st July
  { title: "Registration", starts_at: Time.zone.parse("2027-07-31 09:00"), ends_at: Time.zone.parse("2027-07-31 10:00"), color: "#b7b7b7" },
  { title: "European Championship Semi Finals", starts_at: Time.zone.parse("2027-07-31 10:00"), ends_at: Time.zone.parse("2027-07-31 16:00"), color: "#d5a6bd" },
  { title: "Magic The Gathering Tmt", starts_at: Time.zone.parse("2027-07-31 10:00"), ends_at: Time.zone.parse("2027-07-31 17:00"), color: "#6fa8dc" },
  { title: "Weekend Tmt R1", starts_at: Time.zone.parse("2027-07-31 10:30"), ends_at: Time.zone.parse("2027-07-31 13:30"), color: "#c9daf8" },
  { title: "Weekend Tmt R2", starts_at: Time.zone.parse("2027-07-31 14:30"), ends_at: Time.zone.parse("2027-07-31 17:30"), color: "#c9daf8" },
  { title: "Weekend Tmt R3", starts_at: Time.zone.parse("2027-07-31 19:00"), ends_at: Time.zone.parse("2027-07-31 22:00"), color: "#c9daf8" },
  # Sunday 1st August
  { title: "Group Photo", starts_at: Time.zone.parse("2027-08-01 09:30"), ends_at: Time.zone.parse("2027-08-01 10:00"), color: "#ffd966" },
  { title: "European Championship Finals", starts_at: Time.zone.parse("2027-08-01 10:00"), ends_at: Time.zone.parse("2027-08-01 16:00"), color: "#d5a6bd" },
  { title: "Weekend Tmt R4", starts_at: Time.zone.parse("2027-08-01 10:00"), ends_at: Time.zone.parse("2027-08-01 13:00"), color: "#c9daf8" },
  { title: "Weekend Tmt R5", starts_at: Time.zone.parse("2027-08-01 14:00"), ends_at: Time.zone.parse("2027-08-01 17:00"), color: "#c9daf8" },
  { title: "Registration 2nd week", starts_at: Time.zone.parse("2027-08-01 18:00"), ends_at: Time.zone.parse("2027-08-01 22:00"), color: "#b7b7b7" },
  { title: "Prizegiving", starts_at: Time.zone.parse("2027-08-01 18:00"), ends_at: Time.zone.parse("2027-08-01 19:00"), color: "#ffd966" },
  { title: "SC-CQ Arrival", starts_at: Time.zone.parse("2027-08-01 19:30"), ends_at: Time.zone.parse("2027-08-01 21:30"), color: "#00ff00" },
  # Monday 2nd August
  { title: "Registration", starts_at: Time.zone.parse("2027-08-02 09:00"), ends_at: Time.zone.parse("2027-08-02 10:00"), color: "#b7b7b7" },
  { title: "SC-CQ Sightseeing", starts_at: Time.zone.parse("2027-08-02 10:00"), ends_at: Time.zone.parse("2027-08-02 17:30"), color: "#00ff00" },
  { title: "Main Open R6", starts_at: Time.zone.parse("2027-08-02 11:00"), ends_at: Time.zone.parse("2027-08-02 15:30"), color: "#c9daf8" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-08-02 13:00"), ends_at: Time.zone.parse("2027-08-02 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-02 14:30"), ends_at: Time.zone.parse("2027-08-02 15:30"), color: "#fff2cc" },
  { title: "Rapid R6", starts_at: Time.zone.parse("2027-08-02 16:00"), ends_at: Time.zone.parse("2027-08-02 17:30"), color: "#00ffff" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-02 16:00"), ends_at: Time.zone.parse("2027-08-02 17:00"), color: "#fff2cc" },
  { title: "Panda Team R1", starts_at: Time.zone.parse("2027-08-02 18:00"), ends_at: Time.zone.parse("2027-08-02 21:00"), color: "#ff00ff" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-08-02 18:00"), ends_at: Time.zone.parse("2027-08-02 20:00"), color: "#b6d7a8" },
  { title: "European 13x13 Championship", starts_at: Time.zone.parse("2027-08-02 18:00"), ends_at: Time.zone.parse("2027-08-02 22:00"), color: "#f4cccc" },
  { title: "SC-CQ Welcome Party", starts_at: Time.zone.parse("2027-08-02 18:00"), ends_at: Time.zone.parse("2027-08-02 21:30"), color: "#00ff00" },
  # Tuesday 3rd August
  { title: "Main Open R7", starts_at: Time.zone.parse("2027-08-03 10:00"), ends_at: Time.zone.parse("2027-08-03 14:30"), color: "#c9daf8" },
  { title: "Students R1-3 / ChangQi R1", starts_at: Time.zone.parse("2027-08-03 10:00"), ends_at: Time.zone.parse("2027-08-03 21:30"), color: "#00ff00" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-08-03 12:00"), ends_at: Time.zone.parse("2027-08-03 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-03 13:30"), ends_at: Time.zone.parse("2027-08-03 14:30"), color: "#fff2cc" },
  { title: "Fun go*", starts_at: Time.zone.parse("2027-08-03 15:00"), ends_at: Time.zone.parse("2027-08-03 17:30"), color: "#e06666" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-03 15:00"), ends_at: Time.zone.parse("2027-08-03 16:00"), color: "#fff2cc" },
  { title: "Rapid R7", starts_at: Time.zone.parse("2027-08-03 16:00"), ends_at: Time.zone.parse("2027-08-03 17:30"), color: "#00ffff" },
  { title: "Panda Team R2", starts_at: Time.zone.parse("2027-08-03 18:00"), ends_at: Time.zone.parse("2027-08-03 21:00"), color: "#ff00ff" },
  { title: "European 9x9 Championship", starts_at: Time.zone.parse("2027-08-03 18:00"), ends_at: Time.zone.parse("2027-08-03 22:00"), color: "#f4cccc" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-08-03 18:00"), ends_at: Time.zone.parse("2027-08-03 20:00"), color: "#b6d7a8" },
  # Wednesday 4th August
  { title: "Excursions", starts_at: Time.zone.parse("2027-08-04 10:00"), ends_at: Time.zone.parse("2027-08-04 20:00"), color: "#6fa8dc" },
  { title: "Go Conferences", starts_at: Time.zone.parse("2027-08-04 10:00"), ends_at: Time.zone.parse("2027-08-04 17:00"), color: "#ffd966" },
  { title: "Youth tmt R1", starts_at: Time.zone.parse("2027-08-04 10:00"), ends_at: Time.zone.parse("2027-08-04 12:00"), color: "#f4cccc" },
  { title: "Poker tmt", starts_at: Time.zone.parse("2027-08-04 10:00"), ends_at: Time.zone.parse("2027-08-04 21:00"), color: "#6fa8dc" },
  { title: "Students R4-6 / ChangQi R2", starts_at: Time.zone.parse("2027-08-04 10:00"), ends_at: Time.zone.parse("2027-08-04 21:30"), color: "#00ff00" },
  { title: "Youth tmt R2", starts_at: Time.zone.parse("2027-08-04 12:30"), ends_at: Time.zone.parse("2027-08-04 14:30"), color: "#f4cccc" },
  { title: "Youth tmt R3", starts_at: Time.zone.parse("2027-08-04 15:00"), ends_at: Time.zone.parse("2027-08-04 17:00"), color: "#f4cccc" },
  { title: "Panda Team R3", starts_at: Time.zone.parse("2027-08-04 18:00"), ends_at: Time.zone.parse("2027-08-04 21:00"), color: "#ff00ff" },
  { title: "Youth tmt R4", starts_at: Time.zone.parse("2027-08-04 19:00"), ends_at: Time.zone.parse("2027-08-04 21:00"), color: "#f4cccc" },
  { title: "Prizegiving", starts_at: Time.zone.parse("2027-08-04 21:00"), ends_at: Time.zone.parse("2027-08-04 21:30"), color: "#ffd966" },
  # Thursday 5th August
  { title: "Main Open R8", starts_at: Time.zone.parse("2027-08-05 10:00"), ends_at: Time.zone.parse("2027-08-05 14:30"), color: "#c9daf8" },
  { title: "Students Final / SC-CQ Simultaneous", starts_at: Time.zone.parse("2027-08-05 10:00"), ends_at: Time.zone.parse("2027-08-05 21:30"), color: "#00ff00" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-08-05 12:00"), ends_at: Time.zone.parse("2027-08-05 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-05 13:30"), ends_at: Time.zone.parse("2027-08-05 14:30"), color: "#fff2cc" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-05 15:00"), ends_at: Time.zone.parse("2027-08-05 16:00"), color: "#fff2cc" },
  { title: "Fun go*", starts_at: Time.zone.parse("2027-08-05 15:00"), ends_at: Time.zone.parse("2027-08-05 17:30"), color: "#e06666" },
  { title: "Rapid R8", starts_at: Time.zone.parse("2027-08-05 16:00"), ends_at: Time.zone.parse("2027-08-05 17:30"), color: "#00ffff" },
  { title: "Pair go R1", starts_at: Time.zone.parse("2027-08-05 16:30"), ends_at: Time.zone.parse("2027-08-05 18:00"), color: "#f4cccc" },
  { title: "Tsume go tmt", starts_at: Time.zone.parse("2027-08-05 18:00"), ends_at: Time.zone.parse("2027-08-05 22:00"), color: "#f4cccc" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-08-05 18:00"), ends_at: Time.zone.parse("2027-08-05 20:00"), color: "#b6d7a8" },
  { title: "Pair go R2", starts_at: Time.zone.parse("2027-08-05 18:30"), ends_at: Time.zone.parse("2027-08-05 20:00"), color: "#f4cccc" },
  { title: "Pair go R3", starts_at: Time.zone.parse("2027-08-05 20:30"), ends_at: Time.zone.parse("2027-08-05 22:00"), color: "#f4cccc" },
  # Friday 6th August
  { title: "Main Open R9", starts_at: Time.zone.parse("2027-08-06 10:00"), ends_at: Time.zone.parse("2027-08-06 14:30"), color: "#c9daf8" },
  { title: "ChangQi Finals / SC-CQ Farewell dinner", starts_at: Time.zone.parse("2027-08-06 10:00"), ends_at: Time.zone.parse("2027-08-06 21:30"), color: "#00ff00" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-08-06 12:00"), ends_at: Time.zone.parse("2027-08-06 17:30"), color: "#b6d7a8" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-06 13:30"), ends_at: Time.zone.parse("2027-08-06 14:30"), color: "#fff2cc" },
  { title: "Lecture", starts_at: Time.zone.parse("2027-08-06 15:00"), ends_at: Time.zone.parse("2027-08-06 16:00"), color: "#fff2cc" },
  { title: "Fun go*", starts_at: Time.zone.parse("2027-08-06 15:00"), ends_at: Time.zone.parse("2027-08-06 17:30"), color: "#e06666" },
  { title: "Rapid R9", starts_at: Time.zone.parse("2027-08-06 16:00"), ends_at: Time.zone.parse("2027-08-06 17:30"), color: "#00ffff" },
  { title: "Pair go R4", starts_at: Time.zone.parse("2027-08-06 16:30"), ends_at: Time.zone.parse("2027-08-06 18:00"), color: "#f4cccc" },
  { title: "Simultaneous games", starts_at: Time.zone.parse("2027-08-06 18:00"), ends_at: Time.zone.parse("2027-08-06 20:00"), color: "#b6d7a8" },
  { title: "Pair go Semifinal", starts_at: Time.zone.parse("2027-08-06 18:30"), ends_at: Time.zone.parse("2027-08-06 20:00"), color: "#f4cccc" },
  { title: "Pair go Final", starts_at: Time.zone.parse("2027-08-06 20:30"), ends_at: Time.zone.parse("2027-08-06 22:00"), color: "#f4cccc" },
  { title: "Prizegiving", starts_at: Time.zone.parse("2027-08-06 22:00"), ends_at: Time.zone.parse("2027-08-06 23:00"), color: "#ffd966" },
  # Saturday 7th August
  { title: "Main Open R10", starts_at: Time.zone.parse("2027-08-07 10:00"), ends_at: Time.zone.parse("2027-08-07 14:30"), color: "#c9daf8" },
  { title: "SC-CQ Departure", starts_at: Time.zone.parse("2027-08-07 10:00"), ends_at: Time.zone.parse("2027-08-07 13:00"), color: "#00ff00" },
  { title: "Game reviews by professionals", starts_at: Time.zone.parse("2027-08-07 12:00"), ends_at: Time.zone.parse("2027-08-07 17:30"), color: "#b6d7a8" },
  { title: "Closing with Prizegiving", starts_at: Time.zone.parse("2027-08-07 16:00"), ends_at: Time.zone.parse("2027-08-07 18:00"), color: "#ffd966" }
]

event_group_seeds = [
  { key: "registration", name: "Registration", color: "#b7b7b7" },
  { key: "ceremony", name: "Ceremony and Official", color: "#ffd966" },
  { key: "main_open", name: "Main Open", color: "#c9daf8" },
  { key: "european_championship", name: "European Championship", color: "#d5a6bd" },
  { key: "rapid", name: "Rapid", color: "#00ffff" },
  { key: "senior", name: "Senior Tournament", color: "#f4cccc" },
  { key: "women", name: "Women Tournament", color: "#f4cccc" },
  { key: "team", name: "Team Tournament", color: "#f4cccc" },
  { key: "youth", name: "Youth Tournament", color: "#f4cccc" },
  { key: "pair_go", name: "Pair Go", color: "#f4cccc" },
  { key: "weekend", name: "Weekend Tournament", color: "#c9daf8" },
  { key: "other_side_tournaments", name: "Other Side Tournaments", color: "#f4cccc" },
  { key: "professional", name: "Professional Activities", color: "#b6d7a8" },
  { key: "lectures", name: "Lectures", color: "#fff2cc" },
  { key: "panda_team", name: "Panda Team", color: "#ff00ff" },
  { key: "fun_go", name: "Fun Go", color: "#e06666" },
  { key: "excursions", name: "Excursions", color: "#6fa8dc" },
  { key: "entertainment", name: "Entertainment", color: "#6fa8dc" },
  { key: "student_changqi", name: "Student and ChangQi", color: "#00ff00" },
  { key: "other", name: "Other", color: CalendarEvent::DEFAULT_COLOR }
]

event_groups_by_key = event_group_seeds.each_with_object({}) do |event_group_data, memo|
  event_group = EventGroup.find_or_create_by(key: event_group_data[:key]) do |eg|
    eg.name = event_group_data[:name]
    eg.color = event_group_data[:color]
  end
  memo[event_group.key] = event_group
end

event_group_key_for = lambda do |title, color|
  normalized_title = title.to_s.downcase
  normalized_color = color.to_s.downcase

  case normalized_title
  when /\Apair go\b/
    "pair_go"
  when /\Ayouth tmt\b/
    "youth"
  when /\Awomen tmt\b/
    "women"
  when /\Asenior tmt\b/
    "senior"
  when /\Ateam tmt\b/
    "team"
  when /\Aweekend tmt\b/
    "weekend"
  when /\Amain open\b/
    "main_open"
  when /\Aeuropean championship\b/
    "european_championship"
  when /\Arapid\b/
    "rapid"
  when /\Aregistration\b/
    "registration"
  when /\Aopening ceremony\b|\Avip dinner\b|\Aegf annual general meeting\b|\Aprizegiving\b|\Aclosing with prizegiving\b|\Agroup photo\b/
    "ceremony"
  when /professional|simultaneous games|game reviews/
    "professional"
  when /\Alecture\b/
    "lectures"
  when /\Apanda team\b/
    "panda_team"
  when /\Afun go\*/
    "fun_go"
  when /students|changqi|sc-cq/
    "student_changqi"
  when /\Aexcursions\b/
    "excursions"
  when /\Apoker tmt\b|\Amagic the gathering tmt\b|\Ago conferences\b|\Ajoanna koike\b/
    "entertainment"
  when /\Ablitz\b|\Atsume go tmt\b|\Aeuropean 13x13 championship\b|\Aeuropean 9x9 championship\b/
    "other_side_tournaments"
  else
    case normalized_color
    when "#f4cccc"
      "other_side_tournaments"
    when "#6fa8dc"
      "entertainment"
    when "#00ff00"
      "student_changqi"
    else
      "other"
    end
  end
end

calendar_event_seeds.each do |calendar_event_data|
  explicit_color = calendar_event_data[:color]
  event_group_key = calendar_event_data[:event_group_key] || event_group_key_for.call(calendar_event_data[:title], explicit_color || CalendarEvent::DEFAULT_COLOR)
  event_group = event_groups_by_key.fetch(event_group_key)
  color_override = if explicit_color.present? && explicit_color.downcase != event_group.color.to_s.downcase
    explicit_color
  else
    nil
  end

  calendar_event = CalendarEvent.find_or_initialize_by(title: calendar_event_data[:title], starts_at: calendar_event_data[:starts_at])
  calendar_event.assign_attributes(
    ends_at: calendar_event_data[:ends_at],
    color: color_override,
    event_group: event_group,
    description: calendar_event_data[:description],
    location: calendar_event_data[:location]
  )
  calendar_event.save! if calendar_event.changed?
end

puts "✓ Seeded #{event_group_seeds.size} event groups"
puts "✓ Seeded #{calendar_event_seeds.size} calendar events"
