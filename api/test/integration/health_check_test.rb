require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "api health endpoint returns ok" do
    get "/api/v1/health"

    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end

  test "root health endpoint returns ok" do
    get "/health"

    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end
end
