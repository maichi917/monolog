require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "トップページにOGPとX Cardを設定している" do
    get root_path

    assert_response :success
    assert_select "title", "ものログ"
    assert_select "meta[name='description'][content]"
    assert_select "meta[property='og:type'][content='website']"
    assert_select "meta[property='og:site_name'][content='ものログ']"
    assert_select "meta[property='og:title'][content='ものログ']"
    assert_select "meta[property='og:description'][content]"
    assert_select "meta[property='og:url'][content='http://www.example.com/']"
    assert_select "meta[property='og:image'][content]"
    assert_select "meta[property='og:image:width'][content='1200']"
    assert_select "meta[property='og:image:height'][content='630']"
    assert_select "meta[property='og:locale'][content='ja_JP']"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name='twitter:title'][content='ものログ']"
    assert_select "meta[name='twitter:description'][content]"
    assert_select "meta[name='twitter:image'][content]"

    og_image = css_select("meta[property='og:image']").first["content"]
    assert_match %r{\Ahttp://www\.example\.com/assets/ogp(?:-[a-f0-9]+)?\.png\z}, og_image
  end

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
