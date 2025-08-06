require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get months" do
    get months_url
    assert_response :success
  end

  test "should get formats" do
    get formats_url
    assert_response :success
  end
end
