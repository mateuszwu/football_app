require "application_system_test_case"

class PublicMobileUiTest < ApplicationSystemTestCase
  PUBLIC_GUEST_PATHS = %w[
    /
    /players
    /players/new
    /leaderboards
    /statistics
    /relationships
  ].freeze

  test "guest pages fit a narrow viewport without horizontal overflow" do
    page.driver.browser.manage.window.resize_to(390, 844)

    PUBLIC_GUEST_PATHS.each do |path|
      visit path

      assert_selector "body"
      overflow = page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth + 1")
      refute overflow, "#{path} overflows horizontally at 390px"
    end
  end

  test "player directory filters use an iOS zoom-safe font size" do
    page.driver.browser.manage.window.resize_to(390, 844)
    visit "/players"

    font_size = page.evaluate_script(<<~JS)
      (() => {
        const control = document.querySelector('.players-directory-field input, .players-directory-field select');
        return control ? getComputedStyle(control).fontSize : null;
      })();
    JS

    assert_equal "16px", font_size
  end
end
