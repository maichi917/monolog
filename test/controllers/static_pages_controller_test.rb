require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "利用規約ページを表示できる" do
    get terms_path

    assert_response :success
    assert_select "h1", "利用規約"
  end

  test "フッターから利用規約ページに移動できる" do
    get root_path

    assert_response :success
    assert_select "footer a[href='#{terms_path}']", "利用規約"
  end
end
