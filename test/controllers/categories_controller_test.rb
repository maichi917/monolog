require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "index shows categories for signed-in user" do
    other_user_category = Category.create!(user: users(:two), name: "日用品")

    get categories_path

    assert_response :success
    assert_includes response.body, categories(:hair_care).name
    assert_not_includes response.body, other_user_category.name
    assert_select "form[action='#{categories_path}'] input[name='category[name]']"
    assert_select "input[type='submit'][value='カテゴリを登録する']"
  end

  test "create saves category for signed-in user" do
    assert_difference -> { @user.categories.count }, 1 do
      post categories_path, params: { category: { name: "日用品" } }
    end

    assert_redirected_to categories_path
  end

  test "create rerenders index when category is invalid" do
    assert_no_difference -> { @user.categories.count } do
      post categories_path, params: { category: { name: "" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "カテゴリ名を入力してください"
  end

  test "destroy removes category for signed-in user" do
    category = categories(:hair_care)

    assert_difference -> { @user.categories.count }, -1 do
      delete category_path(category)
    end

    assert_redirected_to categories_path
  end

  test "destroy does not remove another user's category" do
    category = Category.create!(user: users(:two), name: "日用品")

    assert_no_difference -> { Category.count } do
      delete category_path(category)
    end

    assert_response :not_found
  end

  test "index redirects guest to sign-in page" do
    sign_out @user

    get categories_path

    assert_redirected_to new_user_session_path
  end
end
