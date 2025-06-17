require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get stats_index_url
    assert_response :success
  end

  test "should get months" do
    get stats_months_url
    assert_response :success
  end

  test "should get formats" do
    get stats_formats_url
    assert_response :success
  end
end
