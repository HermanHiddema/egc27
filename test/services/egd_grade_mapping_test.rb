require "test_helper"

class EgdGradeMappingTest < ActiveSupport::TestCase
  test "rating_for anchors 1 kyu at 2000 and 1 dan at 2100" do
    assert_equal 2000, EgdGradeMapping.rating_for("1 kyu")
    assert_equal 2100, EgdGradeMapping.rating_for("1 dan")
  end

  test "rating_for steps by 100 per grade" do
    assert_equal 1800, EgdGradeMapping.rating_for("3 kyu")
    assert_equal 2200, EgdGradeMapping.rating_for("2 dan")
  end

  test "rating_for accepts a grade_n integer" do
    # grade_n 29 is 1 kyu, grade_n 30 is 1 dan.
    assert_equal 2000, EgdGradeMapping.rating_for(29)
    assert_equal 2100, EgdGradeMapping.rating_for(30)
  end

  test "rating_for returns nil for blank or unknown grades" do
    assert_nil EgdGradeMapping.rating_for(nil)
    assert_nil EgdGradeMapping.rating_for("")
    assert_nil EgdGradeMapping.rating_for("not a grade")
  end
end
