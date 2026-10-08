require "test_helper"
require "rake"

class FitnessTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("fitness:provision_user")
    @task = Rake::Task["fitness:provision_user"]
    @task.reenable
  end

  test "provisioning a changed email updates the sole user" do
    original_user = users(:primary)
    previous_email = ENV["FITNESS_USER_EMAIL"]
    previous_password = ENV["FITNESS_USER_PASSWORD"]
    ENV["FITNESS_USER_EMAIL"] = "new-owner@example.com"
    ENV["FITNESS_USER_PASSWORD"] = "new-password"

    assert_no_difference -> { User.count } do
      capture_io { @task.invoke }
    end

    provisioned_user = User.sole
    assert_equal original_user.id, provisioned_user.id
    assert_equal "new-owner@example.com", provisioned_user.email_address
    assert_predicate provisioned_user.authenticate("new-password"), :present?
  ensure
    ENV["FITNESS_USER_EMAIL"] = previous_email
    ENV["FITNESS_USER_PASSWORD"] = previous_password
  end
end
