require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = false
  end

  test "throttles magic link requests by IP after limit" do
    10.times do |i|
      post user_magic_link_session_path, params: { user: { email: "user#{i}@example.com" } }, headers: { "REMOTE_ADDR" => "1.2.3.4" }
      assert_response :redirect
    end

    post user_magic_link_session_path, params: { user: { email: "user10@example.com" } }, headers: { "REMOTE_ADDR" => "1.2.3.4" }
    assert_response 429
  end

  test "allows magic link requests under the IP limit" do
    5.times { post user_magic_link_session_path, params: { user: { email: "user@example.com" } }, headers: { "REMOTE_ADDR" => "1.2.3.5" } }

    assert_response :redirect
  end

  test "throttles magic link requests by email after limit" do
    5.times do |i|
      post user_magic_link_session_path,
        params: { user: { email: "throttled@example.com" } },
        headers: { "REMOTE_ADDR" => "10.0.0.#{i + 1}" }
      assert_response :redirect
    end

    post user_magic_link_session_path,
      params: { user: { email: "throttled@example.com" } },
      headers: { "REMOTE_ADDR" => "10.0.0.99" }
    assert_response 429
  end

  test "throttles participant registration by IP after limit" do
    params = {
      participant: {
        first_name: "Jane", last_name: "Doe", email: "jane@example.org",
        participant_type: "player", date_of_birth: "11-02-1995",
        country: "NL", club: "Utrecht", accepted_terms_and_conditions: true,
        accepted_privacy_policy: true
      }
    }

    10.times do
      post participants_path, params: params, headers: { "REMOTE_ADDR" => "2.3.4.5" }
      assert_response :redirect
    end

    post participants_path, params: params, headers: { "REMOTE_ADDR" => "2.3.4.5" }
    assert_response 429
  end

  test "throttles sign-up requests by IP after limit" do
    params = { user: { email: "newuser@example.org", full_name: "Test User", password: "password123", password_confirmation: "password123" } }

    10.times do
      post user_registration_path, params: params, headers: { "REMOTE_ADDR" => "3.4.5.6" }
      assert_includes [200, 302, 422], response.status
    end

    post user_registration_path, params: params, headers: { "REMOTE_ADDR" => "3.4.5.6" }
    assert_response 429
  end
end
