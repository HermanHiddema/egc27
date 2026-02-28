require "test_helper"

class MenuTest < ActiveSupport::TestCase
  test "valid fixture" do
    assert menus(:primary).valid?
  end

  test "requires unique location" do
    duplicate = Menu.new(name: "Another", location: menus(:primary).location)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:location], "has already been taken"
  end
end
