require "test_helper"

class UserConfirmationTest < ActionDispatch::IntegrationTest
  def registration
    post participants_path, params: { participant: {
      first_name: "Jane", last_name: "Doe", email: "confirmation@example.org",
      participant_type: "player", age_group: "18-49", country: "NL",
      club: "Utrecht", gender: "female", image_use_consent: false
    } }
    User.find_by!(email: "confirmation@example.org")
  end

  test "registration confirmation verifies the user, signs them in, and cannot be reused" do
    user = registration
    participant = user.participants.first
    token = user.confirmation_token
    assert_not participant.confirmed?

    assert_difference "NewsletterSubscription.count", 1 do
      get user_confirmation_path, params: { confirmation_token: token }
    end
    assert_redirected_to edit_user_registration_path
    assert user.reload.confirmed?
    assert participant.reload.confirmed?
    get edit_user_registration_path
    assert_response :success

    sign_out user
    get user_confirmation_path, params: { confirmation_token: token }
    assert_not response.redirect?
    assert_match(/already confirmed|invalid/i, response.body)
  end

  test "resending within the confirmation period starts a fresh two-week lifetime" do
    user = registration
    old_token = user.confirmation_token
    travel 1.week
    post resend_registration_confirmation_path(user.participants.first)
    new_token = user.reload.confirmation_token
    assert_not_equal old_token, new_token
    get user_confirmation_path, params: { confirmation_token: old_token }
    assert_not user.reload.confirmed?
    travel 1.week + 1.day
    get user_confirmation_path, params: { confirmation_token: new_token }
    assert user.reload.confirmed?
  end

  test "registration link expires after two weeks and a resend provides a usable link" do
    user = registration
    old_token = user.confirmation_token
    travel 2.weeks + 1.second do
      get user_confirmation_path, params: { confirmation_token: old_token }
      assert_not user.reload.confirmed?
      assert_match(/within 14 days/i, response.body)
      assert_select "input[name=\"user[email]\"][value=?]", user.email

      post resend_registration_confirmation_path(user.participants.first)
      assert_not_equal old_token, user.reload.confirmation_token
      get user_confirmation_path, params: { confirmation_token: old_token }
      assert_not user.reload.confirmed?
      get user_confirmation_path, params: { confirmation_token: user.confirmation_token }
      assert user.reload.confirmed?
    end
  end
end
