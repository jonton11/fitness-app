require "test_helper"

class Api::V1::HealthControllerTest < ActionController::TestCase
  tests Api::V1::HealthController

  test "reports when the database is unavailable" do
    @controller.define_singleton_method(:database_available?) { false }

    get :show

    assert_response :service_unavailable
    assert_equal({ "status" => "unavailable" }, response.parsed_body)
  end
end
