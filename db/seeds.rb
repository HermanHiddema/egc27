# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create or recreate test user with properly hashed password
User.where(email: "test@example.com").destroy_all

user = User.create!(
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123"
)

puts "✓ Test user created: test@example.com / password123"
puts "✓ Password is encrypted: #{user.encrypted_password.present?}"

