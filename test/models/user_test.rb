require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "default role is regular" do
    user = User.new(email: "new@example.com", password: "password123")
    assert_equal "regular", user.role
    assert user.regular?
  end

  test "role can be set to editor" do
    user = User.new(email: "ed@example.com", password: "password123", role: "editor")
    assert user.editor?
    refute user.regular?
    refute user.admin?
  end

  test "role can be set to admin" do
    user = User.new(email: "adm@example.com", password: "password123", role: "admin")
    assert user.admin?
    refute user.editor?
    refute user.regular?
  end

  test "regular user cannot create content" do
    user = users(:one)
    assert user.regular?
    refute user.can_create?
  end

  test "regular user cannot edit content" do
    user = users(:one)
    assert user.regular?
    refute user.can_edit?
  end

  test "regular user cannot delete content" do
    user = users(:one)
    assert user.regular?
    refute user.can_delete?
  end

  test "editor can create content" do
    user = users(:editor)
    assert user.editor?
    assert user.can_create?
  end

  test "editor can edit content" do
    user = users(:editor)
    assert user.editor?
    assert user.can_edit?
  end

  test "editor cannot delete content" do
    user = users(:editor)
    assert user.editor?
    refute user.can_delete?
  end

  test "admin can create content" do
    user = users(:admin)
    assert user.admin?
    assert user.can_create?
  end

  test "admin can edit content" do
    user = users(:admin)
    assert user.admin?
    assert user.can_edit?
  end

  test "admin can delete content" do
    user = users(:admin)
    assert user.admin?
    assert user.can_delete?
  end

  test "can be created without a password for passwordless sign-in" do
    user = User.new(email: "passwordless@example.com", skip_password_validation: true)
    assert user.valid?, "User without password should be valid: #{user.errors.full_messages}"
  end

  test "password_set? is false when no password has been stored" do
    user = User.new(email: "passwordless@example.com", skip_password_validation: true)

    refute user.password_set?
  end

  test "after_confirmation auto-confirms linked participants" do
    user = User.create!(
      email: "confirm_test@example.com",
      skip_password_validation: true,
      confirmation_token: "token123",
      confirmation_sent_at: Time.current
    )
    participant = Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      date_of_birth: Date.new(1990, 1, 1),
      country: "NL",
      club: "Test Club",
      gender: "male",
      image_use_consent: true,
      user: user
    )

    assert_nil participant.confirmed_at

    user.confirm!

    assert_not_nil participant.reload.confirmed_at
  end
end
