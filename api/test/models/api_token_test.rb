require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "issues a token while storing only its digest" do
    record, token = ApiToken.issue!(user: users(:primary), name: "Jonathan's iPhone")

    assert token.start_with?(ApiToken::TOKEN_PREFIX)
    assert_not_equal token, record.token_digest
    assert_equal users(:primary), ApiToken.authenticate(token)
    assert_nil ApiToken.authenticate("invalid")
  end

  test "rotates the token for an existing device name" do
    record, original_token = ApiToken.issue!(user: users(:primary), name: "Jonathan's iPhone")
    rotated_record, rotated_token = ApiToken.issue!(user: users(:primary), name: "Jonathan's iPhone")

    assert_equal record.id, rotated_record.id
    assert_nil ApiToken.authenticate(original_token)
    assert_equal users(:primary), ApiToken.authenticate(rotated_token)
  end
end
