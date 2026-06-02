require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "valid with name and user" do
    category = Category.new(user: users(:one), name: "日用品")

    assert category.valid?
  end

  test "invalid without name" do
    category = Category.new(user: users(:one), name: "")

    assert_not category.valid?
    assert_includes category.errors[:name], "を入力してください"
  end

  test "invalid with name over 20 characters" do
    category = Category.new(user: users(:one), name: "あ" * 21)

    assert_not category.valid?
  end

  test "invalid with duplicate name for same user" do
    category = Category.new(user: users(:one), name: categories(:hair_care).name)

    assert_not category.valid?
  end

  test "valid with same name for different user" do
    category = Category.new(user: users(:two), name: categories(:hair_care).name)

    assert category.valid?
  end
end
