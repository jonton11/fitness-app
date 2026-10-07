require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email and authenticates a valid password" do
    user = User.create!(
      email_address: "  Other@Example.COM ",
      password: "correct-password",
      password_confirmation: "correct-password"
    )

    assert_equal "other@example.com", user.email_address
    assert_predicate user.authenticate("correct-password"), :present?
    assert_not user.authenticate("wrong-password")
  end
end
