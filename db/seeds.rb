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
