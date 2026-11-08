require "test_helper"
require "ostruct"

# == Schema Information
#
# Table name: participants
#
#  id                            :bigint           not null, primary key
#  accepted_privacy_policy       :boolean          default(FALSE), not null
#  accepted_terms_and_conditions :boolean          default(FALSE), not null
#  age_group                     :string           not null
#  club                          :string           not null
#  country                       :string           not null
#  egd_pin                       :string
#  email                         :string           not null
#  first_name                    :string           not null
#  first_week                    :boolean          default(TRUE)
#  gender                        :string
#  image_use_consent             :boolean          default(FALSE), not null
#  last_name                     :string           not null
#  participant_type              :string           default("player"), not null
#  phone                         :string
#  rank                          :integer
#  rating                        :integer
#  second_week                   :boolean          default(TRUE)
#  uuid                          :uuid             not null
#  weekend                       :boolean          default(TRUE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  user_id                       :bigint           not null
#
# Indexes
#
#  index_participants_on_created_at        (created_at)
#  index_participants_on_egd_pin           (egd_pin) UNIQUE
#  index_participants_on_email             (email)
#  index_participants_on_gender            (gender)
#  index_participants_on_participant_type  (participant_type)
#  index_participants_on_phone             (phone)
#  index_participants_on_rating            (rating)
#  index_participants_on_user_id           (user_id)
#  index_participants_on_uuid              (uuid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ParticipantTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  test "refreshes an unpaid ticket price after the pricing tier changes" do
    participant = participants(:three)

    travel_to Date.new(2026, 8, 31) do
      participant.valid?
      assert_equal 19_000, participant.participant_ticket.price_cents
    end

    travel_to Date.new(2026, 9, 1) do
      participant.update!(club: "Another Club")
    end

    assert_equal 22_000, participant.participant_ticket.reload.price_cents
  end

  test "changing the egd pin queues an EGD sync for the participant" do
    participant = participants(:one)

    assert_enqueued_with(job: EgdSyncJob, args: [participant.id]) do
      participant.update!(egd_pin: "12345678")
    end
  end

  test "updates that keep the egd pin do not queue an EGD sync" do
    participant = participants(:one)

    assert_no_enqueued_jobs(only: EgdSyncJob) do
      participant.update!(club: "Another Club")
    end
  end

  test "removing the egd pin does not queue an EGD sync" do
    participant = participants(:one)

    assert_no_enqueued_jobs(only: EgdSyncJob) do
      participant.update!(egd_pin: "")
    end
  end

  test "requires all public registration fields" do
    participant = Participant.new

    assert_not participant.valid?
    assert_includes participant.errors[:first_name], "can't be blank"
    assert_includes participant.errors[:last_name], "can't be blank"
    assert_includes participant.errors[:email], "can't be blank"
    assert_includes participant.errors[:age_group], "must be selected"
    assert_includes participant.errors[:country], "can't be blank"
  end

  test "participant number is the database id offset by 1000" do
    participant = participants(:one)

    assert_equal participant.id + 1000, participant.participant_number
  end

  test "participant number is nil for an unpersisted participant" do
    assert_nil Participant.new.participant_number
  end

  test "age group has a single must be selected error when blank" do
    participant = Participant.new

    assert_not participant.valid?
    assert_equal ["must be selected"], participant.errors[:age_group]
  end

  test "does not surface a user error when email is missing" do
    participant = Participant.new

    assert_not participant.valid?
    assert_includes participant.errors[:email], "can't be blank"
    assert_empty participant.errors[:user]
  end

  test "requires a user even when other fields are present" do
    participant = Participant.new(
      first_name: "Eva",
      last_name: "Jansen",
      email: "eva@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      image_use_consent: true,
      rank: "1 dan"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:user], "can't be blank"
  end

  test "derives rating from rank and ignores submitted rating without an EGD pin" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      club: "Utrecht",
      rank: "3k",
      image_use_consent: true,
      rating: "1789"
    )

    assert participant.valid?
    assert_equal(27, participant.rank)
    # 3 kyu (grade_n 27) -> 2000 + (27 - 29) * 100 = 1800, submitted 1789 ignored.
    assert_equal(1800, participant.rating)
    assert_equal("3 kyu", participant.rank_grade)
  end

  test "keeps the EGD rating when an EGD pin is present" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Jane",
      last_name: "Doe",
      email: "jane.egd@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      club: "Utrecht",
      rank: "3k",
      image_use_consent: true,
      egd_pin: "12345678",
      rating: "1789"
    )

    assert participant.valid?
    # EGD takes priority over the rank-derived rating.
    assert_equal(1789, participant.rating)
  end

  test "falls back to the rank rating when an EGD pin has no rating" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Jane",
      last_name: "Doe",
      email: "jane.norating@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      club: "Utrecht",
      rank: "1 dan",
      image_use_consent: true,
      egd_pin: "12345678",
      rating: ""
    )

    assert participant.valid?
    # 1 dan (grade_n 30) -> 2000 + (30 - 29) * 100 = 2100.
    assert_equal(2100, participant.rating)
  end

  test "leaves rating blank when neither an EGD rating nor a rank is present" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Nina",
      last_name: "Visitor",
      email: "nina@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      image_use_consent: true,
      rating: "1500"
    )

    assert participant.valid?
    assert_nil participant.rating
  end

  test "supports professional grades" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Ilja",
      last_name: "Shikshin",
      email: "ilja@example.org",
      age_group: "18-49",
      country: "RU",
      gender: "male",
      club: "Kazan",
      image_use_consent: true,
      rank: "4p"
    )

    assert participant.valid?
    assert_equal(42, participant.rank)
    assert_equal("4 dan pro", participant.rank_grade)
    # 1 dan pro is equivalent to 7 dan (2700); each further pro grade adds 30.
    assert_equal(2790, participant.rating)
  end

  test "validates age group must be one of the allowed values" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Eva",
      last_name: "Jansen",
      email: "eva@example.org",
      age_group: "25-30",
      country: "NL",
      gender: "female",
      club: "Eindhoven",
      image_use_consent: true,
      rank: "1 dan"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:age_group], "must be selected"
  end

  test "accepts all valid age group values" do
    Participant::AGE_GROUPS.each do |group|
      participant = Participant.new(
        user: users(:one),
        first_name: "Eva",
        last_name: "Jansen",
        email: "eva@example.org",
        age_group: group,
        country: "NL",
        gender: "female",
        club: "Eindhoven",
        image_use_consent: true,
        rank: "1 dan"
      )

      assert participant.valid?, "Expected #{group} to be valid, but got: #{participant.errors.full_messages}"
    end
  end

  test "normalizes country to uppercase iso code" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Ana",
      last_name: "Silva",
      email: "ana@example.org",
      age_group: "18-49",
      country: "pt",
      gender: "female",
      club: "Porto",
      image_use_consent: true,
      rank: "10 kyu"
    )

    assert participant.valid?
    assert_equal("PT", participant.country)
  end

  test "defaults participant type to player" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Lee",
      last_name: "Min",
      email: "lee@example.org",
      age_group: "18-49",
      country: "KR",
      gender: "male",
      club: "Seoul",
      image_use_consent: true,
      rank: "2 dan"
    )

    assert participant.valid?
    assert_equal("player", participant.participant_type)
  end

  test "validates EGD pin must be an 8 digit number" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Lee",
      last_name: "Min",
      email: "lee.pin@example.org",
      age_group: "18-49",
      country: "KR",
      gender: "male",
      club: "Seoul",
      image_use_consent: true,
      rank: "2 dan",
      egd_pin: "1234"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:egd_pin], "must be an 8 digit number"

    participant.egd_pin = "12345678"
    assert participant.valid?
  end

  test "clamps derived rating to the allowed range" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Lee",
      last_name: "Min",
      email: "lee.rating@example.org",
      age_group: "18-49",
      country: "KR",
      gender: "male",
      club: "Seoul",
      image_use_consent: true,
      rank: "30 kyu"
    )

    assert participant.valid?
    # 30 kyu (grade_n 0) -> 2000 + (0 - 29) * 100 = -900, within range.
    assert_equal(-900, participant.rating)
    assert_operator participant.rating, :>=, Participant::MIN_RATING

    # An out-of-range EGD rating is clamped rather than rejected.
    participant.egd_pin = "12345678"
    participant.rating = 9000
    assert participant.valid?
    assert_equal(Participant::MAX_RATING, participant.rating)
  end

  test "normalizes email" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Nora",
      last_name: "Berg",
      email: " Nora.Berg@Example.COM ",
      participant_type: "visitor",
      age_group: "18-49",
      country: "SE",
      gender: "female",
      club: "Stockholm",
      image_use_consent: true,
      rank: "5 kyu"
    )

    assert participant.valid?
    assert_equal("nora.berg@example.com", participant.email)
    assert_equal("visitor", participant.participant_type)
  end

  test "rejects a duplicate EGD pin" do
    participant = participants(:one).dup
    participant.email = "different@example.org"
    participant.user = users(:two)

    assert_not participant.valid?
    assert_includes participant.errors[:egd_pin], "is already registered"
  end

  test "club is optional" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      club: "",
      image_use_consent: true,
      rank: "8 kyu"
    )

    assert participant.valid?
    assert_equal("", participant.club)
  end

  test "normalizes phone to international digits format" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      phone: "(+39) 06 1234 5678"
    )

    assert participant.valid?
    assert_equal("+390612345678", participant.phone)
  end

  test "rejects clearly invalid phone" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      phone: "+12"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:phone], "must be a valid international phone number"
  end

  test "implicitly accepts terms and privacy policy" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true
    )

    assert participant.valid?
    assert_equal true, participant.accepted_terms_and_conditions
    assert_equal true, participant.accepted_privacy_policy
  end

  test "attendance periods default to selected" do
    participant = Participant.new

    assert_equal true, participant.first_week
    assert_equal true, participant.weekend
    assert_equal true, participant.second_week
  end

  test "image consent defaults to nil for new participants" do
    assert_nil Participant.new.image_use_consent
  end

  test "attendance option updates attendance periods" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      attendance_option: "weekend_only"
    )

    assert participant.valid?
    assert_equal false, participant.first_week
    assert_equal true, participant.weekend
    assert_equal false, participant.second_week
  end

  test "rejects unknown attendance option" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      attendance_option: "unexpected"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:attendance_option], "must be selected"
  end

  test "requires explicit image consent choice" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: nil
    )

    assert_not participant.valid?
    assert_includes participant.errors[:image_use_consent], "must be selected"
  end

  test "assigns a uuid on creation" do
    participant = Participant.create!(
      user: users(:one),
      first_name: "Uuid",
      last_name: "Tester",
      email: "uuid_tester@example.org",
      age_group: "18-49",
      gender: "female",
      country: "NL",
      club: "Amsterdam Go Club",
      image_use_consent: true
    )

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, participant.uuid)
  end

  test "to_param returns the uuid" do
    participant = participants(:one)

    assert_equal participant.uuid, participant.to_param
  end

  test "registration_status is Pending when not confirmed" do
    assert_equal "Pending", participants(:unconfirmed).registration_status
  end

  test "registration_status is Confirmed when confirmed without a completed payment" do
    assert_equal "Confirmed", participants(:one).registration_status
  end

  test "registration_status is Paid when a payment has completed" do
    assert participants(:two).paid?
    assert_equal "Paid", participants(:two).registration_status
  end

  test "registration_status is Refund when the payment was refunded" do
    participant = participants(:two)
    participant.payments.update_all(status: "refunded")

    participant.reload
    assert participant.refunded?
    assert_not participant.paid?
    assert_equal "Refund", participant.registration_status
  end

  test "registration_status is Paid when a later payment succeeded after a refund" do
    participant = participants(:two)
    participant.payments.update_all(status: "refunded")
    participant.order.payments.create!(amount_cents: participant.order.amount_cents, description: "New payment", status: "paid")

    participant.reload
    assert_not participant.refunded?
    assert_equal "Paid", participant.registration_status
  end

  test "registration_status is Chargeback when the payment was charged back" do
    participant = participants(:two)
    participant.payments.update_all(status: "charged_back")

    participant.reload
    assert participant.charged_back?
    assert_not participant.paid?
    assert_equal "Chargeback", participant.registration_status
  end

  test "not_refunded excludes participants with a charged-back payment" do
    participant = participants(:two)
    participant.payments.update_all(status: "charged_back")

    assert_not_includes Participant.not_refunded, participant.reload
  end

  test "not_refunded excludes participants with a refunded payment" do
    participant = participants(:two)
    participant.payments.update_all(status: "refunded")

    assert_not_includes Participant.not_refunded, participant.reload
  end

  test "not_refunded keeps participants that paid again after a refund" do
    participant = participants(:two)
    participant.payments.update_all(status: "refunded")
    participant.order.payments.create!(amount_cents: participant.order.amount_cents, description: "New payment", status: "paid")

    assert_includes Participant.not_refunded, participant.reload
  end

  test "blocking_payments? is true for an open payment" do
    assert participants(:one).blocking_payments?
  end

  test "blocking_payments? is false without payments" do
    assert_not participants(:three).blocking_payments?
  end

  test "blocking_payments? is false when all payments are unsuccessful" do
    participant = participants(:one)
    participant.payments.update_all(status: "expired")

    assert_not participant.reload.blocking_payments?
  end

  test "blocking_payments? uses the loaded association when available" do
    participant = participants(:one)
    participant.payments.update_all(status: "failed")
    participant.payments.load

    assert_no_queries do
      assert_not participant.blocking_payments?
    end
  end

  test "deletable? is false for a successful payment" do
    assert_not participants(:two).deletable?
  end

  test "deletable? is false for an open payment" do
    assert_not participants(:one).deletable?
  end

  test "deletable? is false for a refunded payment" do
    participant = participants(:two)
    participant.payments.update_all(status: "refunded")

    assert_not participant.reload.deletable?
  end

  test "deletable? is false for a charged-back payment" do
    participant = participants(:two)
    participant.payments.update_all(status: "charged_back")

    assert_not participant.reload.deletable?
  end

  test "deletable? is true without payments" do
    assert participants(:three).deletable?
  end

  test "changes and deletions are recorded by paper trail" do
    participant = participants(:three)

    assert_difference -> { PaperTrail::Version.where(item_type: "Participant", item_id: participant.id).count }, 1 do
      participant.update!(club: "Rotterdam Go Club")
    end

    assert_difference -> { PaperTrail::Version.where(item_type: "Participant", item_id: participant.id, event: "destroy").count }, 1 do
      participant.destroy!
    end
  end
  # Payment lookups and refreshing
  test "paid_payment returns the most recent completed payment" do
    participant = participants(:two)

    assert_equal payments(:paid_payment), participant.paid_payment
  end

  test "paid_payment is nil without a completed payment" do
    assert_nil participants(:one).paid_payment
  end

  test "pending_payment returns the most recent in-progress payment" do
    participant = participants(:one)

    assert_equal payments(:open_payment), participant.pending_payment
  end

  test "current_payment prefers a completed payment" do
    assert_equal payments(:paid_payment), participants(:two).current_payment
  end

  test "current_payment falls back to an in-progress payment" do
    assert_equal payments(:open_payment), participants(:one).current_payment
  end

  test "current_payment builds a new payment when there is none" do
    participant = participants(:three)

    payment = participant.current_payment

    assert_not payment.persisted?
    assert_equal "open", payment.status
  end

  test "refresh_paid_payments! records a refund reported by Mollie" do
    participant = participants(:two)
    payment = payments(:paid_payment)
    remote = OpenStruct.new(
      id: payment.mollie_payment_id,
      status: "paid",
      amount_refunded: OpenStruct.new(value: BigDecimal("50.00"), currency: "EUR")
    )

    with_mollie_get(->(_id) { remote }) { participant.refresh_paid_payments! }

    assert_equal "refunded", payment.reload.status
    assert_not participant.paid?
  end

  test "refresh_paid_payments! stops at the first payment that is still paid" do
    participant = participants(:two)
    newer_payment = payments(:paid_payment)
    older_payment = participant.order.payments.create!(
      amount_cents: 5_000,
      description: "Older Mollie payment",
      provider: "mollie",
      mollie_payment_id: "tr_paid_older",
      status: "paid",
      created_at: newer_payment.created_at - 1.day,
      updated_at: newer_payment.updated_at - 1.day
    )
    fetched_ids = []

    with_mollie_get(->(id) { fetched_ids << id; OpenStruct.new(id: id, status: "paid") }) do
      participant.refresh_paid_payments!
    end

    assert_equal [newer_payment.mollie_payment_id], fetched_ids
    assert_equal "paid", older_payment.reload.status
  end

  test "refresh_paid_payments! swallows Mollie errors" do
    participant = participants(:two)

    with_mollie_get(->(_id) { raise Mollie::Exception, "boom" }) do
      assert_nothing_raised { participant.refresh_paid_payments! }
    end

    assert_equal "paid", payments(:paid_payment).reload.status
  end

  private

  def with_mollie_get(stub)
    original = Mollie::Payment.method(:get)
    Mollie::Payment.define_singleton_method(:get) { |id| stub.call(id) }
    yield
  ensure
    Mollie::Payment.define_singleton_method(:get, &original)
  end
  test "a visitor needs no ticket, product, or order, even when admission fields are read" do
    visitor = participants(:visitor_one)
    assert_nil visitor.participant_ticket
    assert_equal "all_events", visitor.attendance_option
    assert visitor.first_week
    assert_not visitor.paid?
    assert visitor.deletable?
    assert_nil visitor.reload.participant_ticket
    assert_nil visitor.product
    assert_nil visitor.order
    assert_empty visitor.payments
  end

  test "a visitor cannot acquire a newly created player ticket" do
    ticket = ParticipantTicket.new(participant: participants(:visitor_one))
    assert_not ticket.valid?
    assert_includes ticket.errors[:participant], "must be a player"
  end

  test "changing a visitor into a player creates the ticket and order" do
    participant = participants(:visitor_one)
    assert_difference ["ParticipantTicket.count", "Product.count", "Order.count"], 1 do
      participant.update!(participant_type: "player", attendance_option: "weekend_only")
    end
    assert_equal "weekend_only", participant.reload.attendance_option
    assert_equal participant.participant_ticket, participant.order.products.sole.productable
  end

  test "changing a player into a visitor preserves payment history" do
    participant = participants(:two)
    ticket = participant.participant_ticket
    payment = payments(:paid_payment)
    participant.update!(participant_type: "visitor")
    assert_equal ticket, participant.reload.participant_ticket
    assert_equal payment.order_id, participant.order.id
    assert_includes participant.payments, payment
  end
end
