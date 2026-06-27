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
      skip_password_validation: true
    )
    participant = Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      club: "Test Club",
      gender: "male",
      image_use_consent: true,
      user: user
    )

    assert_nil participant.confirmed_at

    user.after_confirmation

    assert_not_nil participant.reload.confirmed_at
  end

  test "after_confirmation subscribes a user with a participant to the newsletter" do
    user = User.create!(
      email: "newsletter_confirm@example.com",
      skip_password_validation: true
    )
    Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      club: "Test Club",
      gender: "male",
      image_use_consent: true,
      user: user
    )

    user.update_column(:confirmed_at, Time.current)

    assert_difference("NewsletterSubscription.count", 1) do
      user.after_confirmation
    end

    subscription = NewsletterSubscription.find_by(email: user.email)
    assert_not_nil subscription
    assert subscription.subscribed
  end

  test "after_confirmation does not subscribe a user without a participant" do
    user = User.create!(
      email: "no_participant_confirm@example.com",
      skip_password_validation: true
    )

    assert_no_difference("NewsletterSubscription.count") do
      user.after_confirmation
    end
  end

  test "changing email updates the user's participants and newsletter subscription" do
    user = User.create!(email: "before@example.com", skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    participant = Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      gender: "male",
      image_use_consent: true,
      user: user
    )
    subscription = NewsletterSubscription.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email
    )

    user.skip_reconfirmation!
    user.update!(email: "after@example.com")

    assert_equal "after@example.com", participant.reload.email
    assert_equal "after@example.com", subscription.reload.email
  end

  test "changing email normalizes participant and subscription emails" do
    user = User.create!(email: "before2@example.com", skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    participant = Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      gender: "male",
      image_use_consent: true,
      user: user
    )
    subscription = NewsletterSubscription.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email
    )

    user.skip_reconfirmation!
    user.update!(email: "  AFter2@Example.com ")

    assert_equal "after2@example.com", participant.reload.email
    assert_equal "after2@example.com", subscription.reload.email
  end

  test "changing email does not create a subscription when none exists" do
    user = User.create!(email: "nochange@example.com", skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      gender: "male",
      image_use_consent: true,
      user: user
    )

    assert_no_difference("NewsletterSubscription.count") do
      user.skip_reconfirmation!
      user.update!(email: "nochange2@example.com")
    end
  end

  test "confirming a reconfirmation propagates the new email" do
    user = User.create!(email: "reconfirm_before@example.com", skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    participant = Participant.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      gender: "male",
      image_use_consent: true,
      user: user
    )
    subscription = NewsletterSubscription.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email
    )

    user.update!(email: "reconfirm_after@example.com")
    assert_equal "reconfirm_before@example.com", user.reload.email, "email change should be postponed until reconfirmation"

    user.confirm

    assert_equal "reconfirm_after@example.com", user.reload.email
    assert_equal "reconfirm_after@example.com", participant.reload.email
    assert_equal "reconfirm_after@example.com", subscription.reload.email
  end
end
