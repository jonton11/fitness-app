ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module AuthenticatedIntegrationRequests
  TEST_API_TOKEN = "fitness_test_token"

  %i[get post patch put delete head options].each do |method|
    define_method(method) do |path, **options|
      super(path, **authenticated_request_options(options))
    end
  end

  def without_api_authentication
    @without_api_authentication = true
    yield
  ensure
    @without_api_authentication = false
  end

  private

  def authenticated_request_options(options)
    return options if @without_api_authentication

    options.merge(
      headers: {
        "Authorization" => "Bearer #{TEST_API_TOKEN}"
      }.merge(options.fetch(:headers, {}))
    )
  end
end

ActionDispatch::IntegrationTest.prepend(AuthenticatedIntegrationRequests)
