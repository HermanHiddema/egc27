require "test_helper"

module Users
  class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
    test "confirming a user with a single participant redirects to that participant" do
      user = create_unconfirmed_user("single@example.org")
      participant = create_participant_for(user)
      token = confirmation_token_for(user)

      get user_confirmation_path(confirmation_token: token)

      assert_redirected_to participant_path(participant)
    end

    test "confirming a user with multiple participants redirects to the registrations list" do
      user = create_unconfirmed_user("multi@example.org")
      2.times { create_participant_for(user) }
      token = confirmation_token_for(user)

      get user_confirmation_path(confirmation_token: token)

      assert_redirected_to mine_participants_path
    end

    test "confirming a user with no participants redirects to account setup" do
      user = create_unconfirmed_user("noparticipant@example.org")
      token = confirmation_token_for(user)

      get user_confirmation_path(confirmation_token: token)

      assert_redirected_to edit_user_registration_path
    end

    private

    def create_unconfirmed_user(email)
      User.create!(email: email, skip_password_validation: true)
    end

    def create_participant_for(user)
      Participant.create!(
        first_name: "Pat",
        last_name: "Player",
        email: user.email,
        user: user,
        age_group: "18-49",
        gender: "male",
        country: "NL",
        rank: 27,
        accepted_terms_and_conditions: true,
        accepted_privacy_policy: true,
        image_use_consent: true,
        participant_type: "player"
      )
    end

    def confirmation_token_for(user)
      raw, enc = Devise.token_generator.generate(User, :confirmation_token)
      user.update_columns(confirmation_token: enc, confirmation_sent_at: Time.current)
      raw
    end
  end
end
