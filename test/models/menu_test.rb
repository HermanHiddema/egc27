require "test_helper"

# == Schema Information
#
# Table name: menus
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  location   :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_menus_on_location  (location) UNIQUE
#
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
