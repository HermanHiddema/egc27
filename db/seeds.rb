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
create_menu_item.call(menu: header_menu, label: "Schedule", position: 3, page_slug: "schedule")
create_menu_item.call(menu: header_menu, label: "Calendar", position: 4, url: "/calendar")

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

event_seeds = [
  {
    title: "Opening Ceremony",
    description: "Welcome speech and opening announcements for all participants.",
    starts_at: Time.zone.parse("2027-07-24 10:00"),
    ends_at: Time.zone.parse("2027-07-24 11:00"),
    location: "Main Hall"
  },
  {
    title: "Main Tournament Round 1",
    description: "First round of the main open tournament.",
    starts_at: Time.zone.parse("2027-07-25 09:30"),
    ends_at: Time.zone.parse("2027-07-25 13:00"),
    location: "Tournament Area"
  },
  {
    title: "Lecture: Endgame Fundamentals",
    description: "A practical lecture focused on common yose decisions.",
    starts_at: Time.zone.parse("2027-07-26 16:00"),
    ends_at: Time.zone.parse("2027-07-26 17:30"),
    location: "Lecture Room B"
  },
  {
    title: "Blitz Evening",
    description: "Fast-paced blitz matches open to all skill levels.",
    starts_at: Time.zone.parse("2027-07-27 20:00"),
    ends_at: Time.zone.parse("2027-07-27 22:00"),
    location: "Side Event Zone"
  },
  {
    title: "Prize Giving",
    description: "Closing ceremony and prize distribution.",
    starts_at: Time.zone.parse("2027-07-30 18:00"),
    ends_at: Time.zone.parse("2027-07-30 19:00"),
    location: "Main Hall"
  }
]

seeded_events = 0
event_seeds.each do |event_data|
  event = Event.find_or_initialize_by(
    title: event_data[:title],
    starts_at: event_data[:starts_at]
  )

  event.description = event_data[:description]
  event.ends_at = event_data[:ends_at]
  event.location = event_data[:location]
  event.user = user

  if event.new_record?
    event.save!
    seeded_events += 1
  elsif event.changed?
    event.save!
  end
end

puts "✓ Seeded #{seeded_events} calendar events"
