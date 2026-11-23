require "test_helper"

class Admin::ParticipantsControllerTest < ActionDispatch::IntegrationTest
  test "participant details preserve overview filters and link ticket orders" do
    sign_in users(:admin)
    participant = participants(:four)
    ticket = participant.participant_tickets.find(&:valid_admission?)
    filters = { country: "NL", status: ["paid"], payment_status: ["Paid"], sort: "name", direction: "desc" }

    get admin_participant_path(participant, **filters)
    assert_response :success
    assert_select "a[href=?]", admin_participants_path(**filters), text: "Back to participants"
    assert_select "a[href=?]", edit_admin_participant_path(participant, **filters), text: "Edit"
    assert_select "a[href=?]", admin_participant_ticket_path(ticket), text: "Ticket ##{ticket.id}"
    assert_select "a[href=?]", admin_order_path(ticket.order), text: "Order ##{ticket.order.id}"
    assert_select "dt", text: "Registered by User"
    assert_select "a[href=?]", admin_user_path(participant.user), text: participant.user.display_name
    assert_match(/\(\s*<a[^>]*>Ticket ##{ticket.id}<\/a>\s*\)/, response.body)
    assert_select "span", text: "Paid"
    get admin_participant_ticket_path(ticket)
    assert_response :success
  end

  test "participant details retain invalidated ticket history without treating it as valid" do
    sign_in users(:admin)
    participant = participants(:four)
    ticket = participant.participant_tickets.sole
    ticket.update!(invalidated_at: Time.current)

    get admin_participant_path(participant)
    assert_response :success
    assert_match "No valid participant ticket", response.body
    assert_match "Ticket invalidated", response.body
    assert_select "a[href=?]", admin_order_path(ticket.order), text: "Order ##{ticket.order.id}"
  end

  test "overview links to participant details with filters" do
    sign_in users(:admin)
    filters = { name: "Alice", sort: "name", direction: "desc" }
    get admin_participants_path(**filters)
    assert_select "tr[data-controller=clickable-row][data-action=?][data-clickable-row-url-value=?]", "click->clickable-row#navigate", admin_participant_path(participants(:one), **filters)
    assert_select "a[href=?]", admin_participant_path(participants(:one), **filters)
  end

  test "participant details handle visitors without tickets" do
    sign_in users(:admin)
    get admin_participant_path(participants(:visitor_one))
    assert_response :success
    assert_match "No valid participant ticket", response.body
    assert_match "No ticket orders", response.body
  end

  test "participant details require admin access" do
    sign_in users(:one)
    get admin_participant_path(participants(:one))
    assert_redirected_to root_path
    get admin_participant_ticket_path(participants(:one).participant_tickets.first)
    assert_redirected_to root_path
  end

  test "regular user cannot access admin participants index" do
    sign_in users(:one)
    get admin_participants_path
    assert_redirected_to root_path
  end

  test "editor cannot access admin participants index" do
    sign_in users(:editor)
    get admin_participants_path
    assert_redirected_to root_path
  end

  test "unauthenticated user is redirected to sign in" do
    get admin_participants_path
    assert_redirected_to new_user_session_path
  end

  test "admin sees all participants with email, status and edit link" do
    sign_in users(:admin)
    get admin_participants_path

    assert_response :success
    # Includes unconfirmed participants (unlike the public list)
    assert_match "Dave Pending", response.body
    # Shows email addresses
    assert_match "dave@example.org", response.body
    # Status badges for the three states (now the 7th column after strength was added)
    assert_select "tbody tr td:nth-child(7) span", text: "Unconfirmed"
    assert_select "tbody tr td:nth-child(7) span", text: "User confirmed"
    assert_select "tbody tr td:nth-child(7) span", text: "Paid"
    # Participant number (database id offset by 1000) in the first column
    assert_select "tbody tr td:nth-child(1)", text: (participants(:one).id + 1000).to_s
    # Edit link
    assert_select "a[href='#{edit_admin_participant_path(participants(:one))}']", text: "Edit"
    # Payment action depends on existing payment provider.
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:three))}'] button", text: "Add payment"
    assert_select "a[href='#{edit_admin_participant_payment_path(participants(:four), payments(:manual_payment))}']", text: "Edit payment"
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:one))}'] button", text: "Add payment"
    assert_select "a[href='#{edit_admin_participant_payment_path(participants(:one), payments(:open_payment))}']", count: 0
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:visitor_one))}']", count: 0
  end

  test "admin index loads registration payment statuses in batches" do
    sign_in users(:admin)
    status_queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      status_queries << sql if sql.match?(/SELECT .*FROM "payments".*participant_tickets.*invalidated_at/im)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get admin_participants_path
    end

    assert_response :success
    assert_empty status_queries
  end

  test "admin participant count reflects zero matching results" do
    sign_in users(:admin)
    get admin_participants_path(name: "No matching participant")

    assert_response :success
    assert_select "#participant-count", text: "0 participants"
  end

  test "admin participant count uses singular wording for one matching result" do
    sign_in users(:admin)
    get admin_participants_path(name: "Alice Smith")

    assert_response :success
    assert_select "#participant-count", text: "1 participant"
  end

  test "admin participant count uses plural wording for multiple results" do
    sign_in users(:admin)
    get admin_participants_path

    assert_response :success
    assert_select "#participant-count", text: "#{Participant.count} participants"
  end

  test "admin sees an add payment link when existing payments can never succeed" do
    sign_in users(:admin)
    payments(:open_payment).update!(status: "expired")

    get admin_participants_path

    assert_response :success
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:one))}'] button", text: "Add payment"
  end

  test "admin sees an add payment link when the latest manual payment failed" do
    sign_in users(:admin)
    payments(:manual_payment).update_columns(status: "failed")

    get admin_participants_path

    assert_response :success
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:four))}'] button", text: "Add payment"
    assert_select "a[href='#{edit_admin_participant_payment_path(participants(:four), payments(:manual_payment))}']", count: 0
  end

  test "admin can open the edit form when no payment exists" do
    sign_in users(:admin)
    get edit_admin_participant_path(participants(:three))

    assert_response :success
    assert_select "form[action='#{admin_participant_path(participants(:three))}']"
    assert_select "input[name='participant[email]'][readonly]"
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:three))}'] button", text: "Add payment"
  end

  test "admin edit page for participant with mollie payment links to order review" do
    sign_in users(:admin)
    get edit_admin_participant_path(participants(:one))

    assert_response :success
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:one))}'] button", text: "Add payment"
    assert_select "a[href='#{edit_admin_participant_payment_path(participants(:one), payments(:open_payment))}']", count: 0
  end

  test "admin edit page for participant with manual payment shows edit payment link" do
    sign_in users(:admin)
    get edit_admin_participant_path(participants(:four))

    assert_response :success
    assert_select "a[href='#{edit_admin_participant_payment_path(participants(:four), payments(:manual_payment))}']", text: "Edit payment"
  end

  test "admin edit page for participant with only canceled payments shows record payment link" do
    sign_in users(:admin)
    payments(:open_payment).update!(status: "canceled")

    get edit_admin_participant_path(participants(:one))

    assert_response :success
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:one))}'] button", text: "Add payment"
  end

  test "admin edit page for visitor does not show record payment link" do
    sign_in users(:admin)
    get edit_admin_participant_path(participants(:visitor_one))

    assert_response :success
    assert_select "form[action='#{add_payment_admin_participant_path(participants(:visitor_one))}']", count: 0
  end

  test "admin can update participant details" do
    sign_in users(:admin)

    patch admin_participant_path(participants(:one)), params: {
      participant: {
        first_name: "Alicia",
        last_name: "Smith",
        gender: "female",
        age_group: "18-49",
        country: "NL",
        participant_type: "player",
        club: "Rotterdam Go Club"
      }
    }

    assert_redirected_to admin_participants_path
    participant = participants(:one).reload
    assert_equal "Alicia", participant.first_name
    assert_equal "Rotterdam Go Club", participant.club
    assert_equal "alice@example.org", participant.email
  end

  test "admin changing the egd pin queues an EGD sync for the participant" do
    sign_in users(:admin)
    participant = participants(:one)

    assert_enqueued_with(job: EgdSyncJob, args: [participant.id]) do
      patch admin_participant_path(participant), params: { participant: { egd_pin: "12345678" } }
    end

    assert_redirected_to admin_participants_path
    assert_equal "12345678", participant.reload.egd_pin
  end

  test "admin update with invalid data re-renders the edit form" do
    sign_in users(:admin)

    patch admin_participant_path(participants(:one)), params: {
      participant: { first_name: "" }
    }

    assert_response :unprocessable_entity
    assert_equal "Alice", participants(:one).reload.first_name
  end

  test "editor cannot update a participant" do
    sign_in users(:editor)

    patch admin_participant_path(participants(:one)), params: {
      participant: { first_name: "Hacked" }
    }

    assert_redirected_to root_path
    assert_equal "Alice", participants(:one).reload.first_name
  end

  test "admin can filter by country" do
    sign_in users(:admin)
    get admin_participants_path(country: "DE")

    assert_response :success
    assert_match "Bob Jones", response.body
    assert_no_match "Alice Smith", response.body
  end

  test "admin can filter by full participant name" do
    sign_in users(:admin)
    get admin_participants_path(name: "Alice Smith")

    assert_response :success
    assert_match "Alice Smith", response.body
    assert_no_match "Bob Jones", response.body
  end

  test "admin can filter by status pending" do
    sign_in users(:admin)
    get admin_participants_path(status: "unconfirmed")

    assert_response :success
    assert_match "Dave Pending", response.body
    assert_no_match "Alice Smith", response.body
    assert_no_match "Bob Jones", response.body
  end

  test "admin can filter by status paid" do
    sign_in users(:admin)
    get admin_participants_path(status: "paid")

    assert_response :success
    # Bob (fixture two) has a completed payment
    assert_match "Bob Jones", response.body
    assert_no_match "Alice Smith", response.body
    assert_no_match "Dave Pending", response.body
  end

  test "status filtering and sorting ignore invalidated tickets and canceled orders" do
    participants(:two).participant_tickets.sole.update_columns(invalidated_at: Time.current)
    orders(:four).update_columns(cancelled_at: Time.current)
    sign_in users(:admin)

    get admin_participants_path(status: "paid")
    assert_no_match "Bob Jones", response.body
    assert_no_match participants(:four).email, response.body

    get admin_participants_path(status: "user_confirmed", sort: "status")
    assert_match "Bob Jones", response.body
    assert_match participants(:four).email, response.body
    assert_select "tbody tr", text: /Bob Jones.*User confirmed/m

    get admin_participants_path(sort: "status", direction: "asc")
    statuses = css_select("tbody tr td:nth-child(7)").map { |cell| cell.text.strip }
    status_order = Participant::STATUSES.each_with_index.to_h { |status, i| [Participant.status_label(status), i] }
    assert_equal statuses.sort_by { |status| status_order.fetch(status) }, statuses
  end

  test "admin can filter by status confirmed" do
    sign_in users(:admin)
    get admin_participants_path(status: "user_confirmed")

    assert_response :success
    # Alice is confirmed without a completed payment
    assert_match "Alice Smith", response.body
    # Bob is paid, so excluded from the confirmed filter
    assert_no_match "Bob Jones", response.body
    # Dave is unconfirmed
    assert_no_match "Dave Pending", response.body
  end

  test "admin can set, filter, and clear each override" do
    sign_in users(:admin)
    participant = participants(:two)
    Participant::ADMIN_STATUSES.each do |status|
      patch admin_participant_path(participant), params: { participant: { admin_status: status } }
      assert_redirected_to admin_participants_path
      assert_equal status, participant.reload.status
      get admin_participants_path(status: status)
      expected_label = status == "participation_canceled" ? "Canceled" : Participant.status_label(status)
      assert_select "tbody tr", text: /Bob Jones.*#{Regexp.escape(expected_label)}/m
      get edit_admin_participant_path(participant)
      assert_select "select[name='participant[admin_status]'] option[selected]", text: Participant.status_label(status)
      assert_match "Admin override", response.body
    end
    patch admin_participant_path(participant), params: { participant: { admin_status: "" } }
    assert_nil participant.reload.admin_status
    assert_equal "paid", participant.status
    get edit_admin_participant_path(participant)
    assert_match "Automatic status", response.body
  end

  test "non admins cannot set or clear an override" do
    participant = participants(:one)
    participant.update!(admin_status: "needs_refund")
    sign_in users(:one)
    patch admin_participant_path(participant), params: { participant: { admin_status: "" } }
    assert_redirected_to root_path
    assert_equal "needs_refund", participant.reload.admin_status
    patch participant_path(participant), params: { participant: { admin_status: "ticket_refunded" } }
    assert_equal "needs_refund", participant.reload.admin_status
  end

  test "admin can sort by email ascending" do
    sign_in users(:admin)
    get admin_participants_path(sort: "email", direction: "asc")

    assert_response :success
    emails = css_select("tbody tr td:nth-child(2)").map { |td| td.text.strip }
    assert_equal emails.sort, emails
  end

  test "admin can sort by status" do
    participants(:one).update!(admin_status: "needs_refund")
    participants(:two).update!(admin_status: "ticket_refunded")
    sign_in users(:admin)
    get admin_participants_path(sort: "status", direction: "asc")
    assert_response :success
    statuses = css_select("tbody tr td:nth-child(7)").map { |td| td.text.strip }
    order = Participant::STATUSES.each_with_index.to_h { |status, i| [Participant.status_label(status), i] }
    assert_equal statuses.sort_by { |status| order.fetch(status) }, statuses
  end

  test "invalid sort and status params fall back to defaults" do
    sign_in users(:admin)
    get admin_participants_path(sort: "bogus", status: "bogus")

    assert_response :success
    # Default sort is by name; all participants remain visible
    assert_match "Alice Smith", response.body
    assert_match "Dave Pending", response.body
  end
  test "non-admins cannot delete participants" do
    sign_in users(:editor)

    assert_no_difference "Participant.count" do
      delete admin_participant_path(participants(:three))
    end

    assert_redirected_to root_path
  end

  test "admin can delete a participant without successful payments" do
    sign_in users(:admin)
    participant = participants(:three).dup
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.save!

    assert_difference "Participant.count", -1 do
      delete admin_participant_path(participant)
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participant was successfully deleted.", flash[:notice]
    assert_not Participant.exists?(participant.id)
    assert User.exists?(users(:one).id)
  end

  test "admin cannot delete a participant whose ticket is in a submitted order" do
    sign_in users(:admin)

    assert_no_difference "Participant.count" do
      delete admin_participant_path(participants(:three))
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participants in a submitted order cannot be deleted.", flash[:alert]
  end

  test "admin cannot delete a participant with a successful payment" do
    sign_in users(:admin)

    assert_no_difference "Participant.count" do
      delete admin_participant_path(participants(:two))
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participants with a successful payment cannot be deleted.", flash[:alert]
  end

  test "admin cannot delete a participant with an open payment" do
    sign_in users(:admin)

    assert_no_difference "Participant.count" do
      delete admin_participant_path(participants(:one))
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participants with an open or pending payment cannot be deleted.", flash[:alert]
  end

  test "admin cannot delete a participant with refunded payments" do
    sign_in users(:admin)
    participants(:two).payments.update_all(status: "paid", amount_refunded_cents: 5_000)

    assert_no_difference "Participant.count" do
      delete admin_participant_path(participants(:two))
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participants with refunded payments cannot be deleted.", flash[:alert]
  end

  test "admin can delete the last participant of a user together with the user" do
    sign_in users(:admin)
    user = User.create!(email: "delete-last@example.org", skip_password_validation: true)
    participant = participants(:three).dup
    participant.user = user
    participant.email = user.email
    participant.egd_pin = nil
    participant.uuid = SecureRandom.uuid
    participant.save!

    assert_difference ["Participant.count", "User.count"], -1 do
      delete admin_participant_path(participant), params: { delete_user: "1" }
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participant and user account were successfully deleted.", flash[:notice]
    assert_not User.exists?(user.id)
  end

  test "admin deleting their own last participant keeps the user account" do
    sign_in users(:admin)
    participant = Participant.create!(
      user: users(:admin),
      first_name: "Admin",
      last_name: "Self",
      email: "admin-self@example.com",
      age_group: "18-49",
      gender: "female",
      country: "NL",
      club: "Amsterdam Go Club",
      rank: 27,
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
      image_use_consent: false,
      participant_type: "player"
    )

    assert_difference "Participant.count", -1 do
      delete admin_participant_path(participant), params: { delete_user: "1" }
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participant was successfully deleted. The user account was kept.", flash[:notice]
    assert User.exists?(users(:admin).id)
  end

  test "the user is kept when the delete user box is unchecked" do
    participants(:unconfirmed).update_column(:user_id, users(:dave).id)
    sign_in users(:admin)

    assert_no_difference "User.count" do
      delete admin_participant_path(participants(:unconfirmed))
    end

    assert User.exists?(users(:dave).id)
    assert_redirected_to admin_participants_path
  end

  test "the user is kept when other participants remain" do
    participants(:unconfirmed).update_column(:user_id, users(:dave).id)
    sign_in users(:admin)

    assert_no_difference "User.count" do
      delete admin_participant_path(participants(:unconfirmed)), params: { delete_user: "1" }
    end

    assert User.exists?(users(:dave).id)
  end

  test "the user is kept when they still have authored site content" do
    participants(:unconfirmed).update_column(:user_id, users(:dave).id)
    sign_in users(:admin)
    Article.create!(title: "Article", content_html: "<p>Details</p>", user: users(:dave))

    assert_no_difference "User.count" do
      delete admin_participant_path(participants(:unconfirmed)), params: { delete_user: "1" }
    end

    assert_redirected_to admin_participants_path
    assert_equal "Participants in a submitted order cannot be deleted.", flash[:alert]
    assert User.exists?(users(:dave).id)
  end

  test "admin edit page hides the user-delete option for a user with authored site content" do
    participants(:unconfirmed).update_column(:user_id, users(:dave).id)
    sign_in users(:admin)
    Article.create!(title: "Article", content_html: "<p>Details</p>", user: users(:dave))

    get edit_admin_participant_path(participants(:unconfirmed))

    assert_response :success
    assert_select "input[name='delete_user']", count: 0
    assert_match "cannot be deleted", response.body
  end

  test "admin edit page offers deletion with a warning for the last participant of a user" do
    participants(:unconfirmed).update_column(:user_id, users(:dave).id)
    sign_in users(:admin)
    get edit_admin_participant_path(participants(:unconfirmed))

    assert_response :success
    assert_select "input[name='delete_user']", count: 0
    assert_match "cannot be deleted", response.body
  end

  test "admin edit page hides the user-delete option for their own last participant" do
    sign_in users(:admin)
    participant = Participant.create!(
      user: users(:admin),
      first_name: "Own",
      last_name: "Admin",
      email: "admin-own@example.com",
      age_group: "18-49",
      gender: "female",
      country: "DE",
      club: "Berlin Go Club",
      rank: 30,
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
      image_use_consent: false,
      participant_type: "player"
    )

    get edit_admin_participant_path(participant)

    assert_response :success
    assert_select "input[name='delete_user']", count: 0
    assert_match "signed-in admin account", response.body
  end

  test "admin edit page hides deletion for participants with a successful payment" do
    sign_in users(:admin)

    get edit_admin_participant_path(participants(:two))

    assert_response :success
    assert_select "input[name='delete_user']", count: 0
    assert_match "successful payment", response.body
  end

  test "admin edit page hides deletion for participants with an open payment" do
    sign_in users(:admin)

    get edit_admin_participant_path(participants(:one))

    assert_response :success
    assert_select "input[name='delete_user']", count: 0
    assert_match "open or pending payment", response.body
  end

  test "admin edit page hides deletion for participants with refunded payments" do
    sign_in users(:admin)
    participants(:two).payments.update_all(status: "paid", amount_refunded_cents: 5_000)

    get edit_admin_participant_path(participants(:two))

    assert_response :success
    assert_select "input[name='delete_user']", count: 0
    assert_match "refunded payments", response.body
  end

  test "admin can trigger an EGD synchronization" do
    sign_in users(:admin)

    assert_enqueued_with(job: EgdSyncJob) do
      post sync_egd_admin_participants_path
    end

    assert_redirected_to admin_participants_path
    assert_equal "EGD synchronization has been started.", flash[:notice]
  end

  test "regular user cannot trigger an EGD synchronization" do
    sign_in users(:one)

    assert_no_enqueued_jobs(only: EgdSyncJob) do
      post sync_egd_admin_participants_path
    end

    assert_redirected_to root_path
  end
end
