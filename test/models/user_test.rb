require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid with email including domain suffix" do
    user = User.new(name: "テストユーザー", email: "user@example.com", password: "password")

    assert user.valid?
  end

  test "invalid without email domain suffix" do
    user = User.new(name: "テストユーザー", email: "admin@admin", password: "password")

    assert_not user.valid?
    assert_includes user.errors[:email], "の形式が正しくありません"
  end
end
