require "test_helper"

class MenuItemTest < ActiveSupport::TestCase
  test "valid fixture" do
    assert menu_items(:schedule).valid?
  end

  test "requires destination" do
    item = MenuItem.new(menu: menus(:primary), label: "Missing destination")

    assert_not item.valid?
    assert_includes item.errors[:base], "must have either a page or a URL"
  end

  test "cannot have both page and url" do
    item = MenuItem.new(
      menu: menus(:primary),
      label: "Both",
      page: pages(:one),
      url: "https://example.com"
    )

    assert_not item.valid?
    assert_includes item.errors[:base], "choose either a page or a URL, not both"
  end

  test "parent must belong to same menu" do
    item = MenuItem.new(
      menu: menus(:footer),
      parent: menu_items(:schedule),
      label: "Wrong parent menu",
      url: "https://example.com"
    )

    assert_not item.valid?
    assert_includes item.errors[:parent_id], "must belong to the same menu"
  end
end
