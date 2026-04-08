require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @previous_rack_attack_enabled = Rack::Attack.enabled
    @previous_rack_attack_cache_store = Rack::Attack.cache.store

    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
    Rack::Attack.cache.store = @previous_rack_attack_cache_store
    Rack::Attack.enabled = @previous_rack_attack_enabled
  end

  test "throttles magic link requests by IP after limit" do
    freeze_time do
      10.times do |i|
        post user_magic_link_session_path, params: { user: { email: "user#{i}@example.com" } }, headers: { "REMOTE_ADDR" => "1.2.3.4" }
        assert_response :redirect
      end

      post user_magic_link_session_path, params: { user: { email: "user10@example.com" } }, headers: { "REMOTE_ADDR" => "1.2.3.4" }
      assert_response 429
      assert response.headers["Retry-After"].to_i.positive?
    end
  end

  test "allows magic link requests under the IP limit" do
    freeze_time do
      5.times do
        post user_magic_link_session_path, params: { user: { email: "user@example.com" } }, headers: { "REMOTE_ADDR" => "1.2.3.5" }
        assert_response :redirect
      end
    end
  end

  test "throttles magic link requests by email after limit" do
    freeze_time do
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
      assert response.headers["Retry-After"].to_i.positive?
    end
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

    freeze_time do
      10.times do
        post participants_path, params: params, headers: { "REMOTE_ADDR" => "2.3.4.5" }
        assert_response :redirect
      end

      post participants_path, params: params, headers: { "REMOTE_ADDR" => "2.3.4.5" }
      assert_response 429
      assert response.headers["Retry-After"].to_i.positive?
    end
  end

  test "throttles sign-up requests by IP after limit" do
    params = { user: { email: "newuser@example.org", full_name: "Test User", password: "password123", password_confirmation: "password123" } }

    freeze_time do
      10.times do
        post user_registration_path, params: params, headers: { "REMOTE_ADDR" => "3.4.5.6" }
        assert_includes [200, 302, 422], response.status
      end

      post user_registration_path, params: params, headers: { "REMOTE_ADDR" => "3.4.5.6" }
      assert_response 429
      assert response.headers["Retry-After"].to_i.positive?
    end
  end

  test "throttles password reset requests by IP after limit" do
    freeze_time do
      5.times do |i|
        post user_password_path, params: { user: { email: "reset#{i}@example.com" } }, headers: { "REMOTE_ADDR" => "4.5.6.7" }
        assert_includes [200, 302, 422], response.status
      end

      post user_password_path, params: { user: { email: "reset5@example.com" } }, headers: { "REMOTE_ADDR" => "4.5.6.7" }
      assert_response 429
      assert response.headers["Retry-After"].to_i.positive?
    end
  end

  test "throttles password reset requests by email after limit" do
    freeze_time do
      3.times do |i|
        post user_password_path,
          params: { user: { email: "reset@example.com" } },
          headers: { "REMOTE_ADDR" => "20.0.0.#{i + 1}" }
        assert_includes [200, 302, 422], response.status
      end

      post user_password_path,
        params: { user: { email: "reset@example.com" } },
        headers: { "REMOTE_ADDR" => "20.0.0.99" }
      assert_response 429
      assert response.headers["Retry-After"].to_i.positive?
    end
  end

  test "throttles confirmation email resend by IP after limit" do
    params = { user: { email: "unconfirmed@example.com" } }

    freeze_time do
      5.times do
        post user_confirmation_path, params: params, headers: { "REMOTE_ADDR" => "5.6.7.8" }
        assert_includes [200, 302, 422], response.status
      end

      post user_confirmation_path, params: params, headers: { "REMOTE_ADDR" => "5.6.7.8" }
      assert_response 429
      assert response.headers["Retry-After"].to_i.positive?
    end
  end
end
