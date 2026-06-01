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

  test "プライバシーポリシーページを表示できる" do
    get privacy_path

    assert_response :success
    assert_select "h1", "プライバシーポリシー"
  end

  test "フッターからプライバシーポリシーページに移動できる" do
    get root_path

    assert_response :success
    assert_select "footer a[href='#{privacy_path}']", "プライバシーポリシー"
  end

  test "お問い合わせページを表示できる" do
    get contact_path

    assert_response :success
    assert_select "h1", "お問い合わせ"
    assert_select "p", "お問い合わせ窓口を準備中です"
  end

  test "フッターからお問い合わせページに移動できる" do
    get root_path

    assert_response :success
    assert_select "footer a[href='#{contact_path}']", "お問い合わせ"
  end
end
