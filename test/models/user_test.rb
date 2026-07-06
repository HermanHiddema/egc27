require "test_helper"

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  full_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  magic_link_token       :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :string           default("regular"), not null
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
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

  test "password confirmation must match when setting a password" do
    user = users(:one)

    user.password = "newpassword123"
    user.password_confirmation = "differentpassword123"

    refute user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
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

  test "destroying a user destroys linked participants" do
    user = User.create!(email: "destroy_test@example.com", skip_password_validation: true)
    participant = Participant.create!(
      first_name: "Destroy",
      last_name: "Me",
      email: user.email,
      age_group: "18-49",
      country: "NL",
      club: "Test Club",
      gender: "male",
      image_use_consent: true,
      user: user
    )

    assert_difference("Participant.count", -1) do
      user.destroy
    end

    assert_not Participant.exists?(participant.id)
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

  test "changing email does not update newsletter subscription when user has no participants" do
    user = User.create!(email: "nopart@example.com", skip_password_validation: true)
    user.update_column(:confirmed_at, Time.current)
    subscription = NewsletterSubscription.create!(
      first_name: "Test",
      last_name: "Person",
      email: user.email
    )

    user.skip_reconfirmation!
    user.update!(email: "nopart2@example.com")

    assert_equal "nopart@example.com", subscription.reload.email
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
