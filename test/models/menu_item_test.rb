require "test_helper"

# == Schema Information
#
# Table name: menu_items
#
#  id              :bigint           not null, primary key
#  label           :string           not null
#  open_in_new_tab :boolean          default(FALSE), not null
#  position        :integer          default(0), not null
#  url             :string
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  menu_id         :bigint           not null
#  page_id         :bigint
#  parent_id       :bigint
#
# Indexes
#
#  index_menu_items_on_menu_id                             (menu_id)
#  index_menu_items_on_menu_id_and_parent_id_and_position  (menu_id,parent_id,position)
#  index_menu_items_on_page_id                             (page_id)
#  index_menu_items_on_parent_id                           (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (menu_id => menus.id)
#  fk_rails_...  (page_id => pages.id)
#  fk_rails_...  (parent_id => menu_items.id)
#
class MenuItemTest < ActiveSupport::TestCase
  test "valid fixture" do
    assert menu_items(:schedule).valid?
  end

  test "allows empty destination for placeholder items" do
    item = MenuItem.new(menu: menus(:primary), label: "Missing destination")

    assert item.valid?
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

  test "allows local path destination" do
    item = MenuItem.new(
      menu: menus(:primary),
      label: "Local path",
      url: "/participants"
    )

    assert item.valid?
  end

  test "allows hash destination" do
    item = MenuItem.new(
      menu: menus(:primary),
      label: "Hash destination",
      url: "#"
    )

    assert item.valid?
  end

  test "rejects invalid url destination" do
    item = MenuItem.new(
      menu: menus(:primary),
      label: "Invalid URL",
      url: "not-a-url"
    )

    assert_not item.valid?
    assert_includes item.errors[:url], "must be a full URL or a local path starting with /"
  end

  test "rejects local path with spaces" do
    item = MenuItem.new(
      menu: menus(:primary),
      label: "Spaced path",
      url: "/foo bar"
    )

    assert_not item.valid?
    assert_includes item.errors[:url], "must be a full URL or a local path starting with /"
  end

  test "strips leading and trailing whitespace from url" do
    item = MenuItem.new(
      menu: menus(:primary),
      label: "Whitespace url",
      url: "  /participants  "
    )

    assert item.valid?
    assert_equal "/participants", item.url
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
