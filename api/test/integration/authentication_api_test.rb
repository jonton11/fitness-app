require "test_helper"

class AuthenticationApiTest < ActionDispatch::IntegrationTest
  test "keeps health checks public" do
    without_api_authentication do
      get "/api/v1/health"
    end

    assert_response :success
  end

  test "requires authentication for domain endpoints" do
    without_api_authentication do
      get "/api/v1/exercises"
    end

    assert_response :unauthorized
    assert_equal(
      {
        "field" => "base",
        "code" => "unauthorized",
        "message" => "Authentication required"
      },
      response.parsed_body.fetch("errors").first
    )
  end

  test "accepts a provisioned bearer token" do
    get "/api/v1/exercises"

    assert_response :success
  end

  test "creates and destroys a browser session" do
    without_api_authentication do
      assert_difference -> { Session.count }, 1 do
        post "/api/v1/session", params: {
          session: {
            email_address: "OWNER@example.com",
            password: "correct-password"
          }
        }
      end

      assert_response :created
      assert_equal users(:primary).id, response.parsed_body.dig("user", "id")
      set_cookie = response.headers.fetch("Set-Cookie").downcase
      assert_includes set_cookie, "httponly"
      assert_includes set_cookie, "samesite=strict"

      get "/api/v1/session"
      assert_response :success

      assert_difference -> { Session.count }, -1 do
        delete "/api/v1/session"
      end
      assert_response :no_content

      get "/api/v1/session"
      assert_response :unauthorized
    end
  end

  test "rejects invalid browser credentials" do
    without_api_authentication do
      post "/api/v1/session", params: {
        session: {
          email_address: users(:primary).email_address,
          password: "wrong-password"
        }
      }
    end

    assert_response :unauthorized
    assert_equal "invalid", response.parsed_body.dig("errors", 0, "code")
    assert_equal "email_address", response.parsed_body.dig("errors", 0, "field")
  end
end
