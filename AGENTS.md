# AI Instructions for egc27

This file defines project-specific guidance for AI coding agents working in this repository.

## Core Principles
- Prefer standard Rails conventions over custom patterns.
- Keep changes small, readable, and easy to review.
- Preserve existing architecture and visual style unless explicitly asked to redesign.
- Never make destructive git changes unless explicitly requested.

## Stack and Architecture
- Rails 8.1 app with Hotwire (Turbo + Stimulus), importmap, and Tailwind.
- PostgreSQL database across environments.
- Authentication via Devise.
- Controllers inherit from `ApplicationController`.

## Implementation Best Practices
- Use strong params for all controller writes.
- Add model validations for required fields and data format constraints.
- Keep business rules in models/services, not in views.
- Prefer service objects for external API integrations.
- For date input/output, use European format expectations (day before month) where requested.
- For participant country storage, keep ISO 3166-1 alpha-2 code semantics.

## Frontend Best Practices
- Use Stimulus controllers for client-side behavior.
- Keep form behavior accessible and resilient (keyboard and mouse friendly).
- Avoid adding heavy dependencies when native browser APIs are sufficient.
- Keep class naming and UI patterns consistent with existing forms.

## Testing and Verification
- Add or update tests whenever behavior changes.
- Prioritize model and controller tests for business logic and params.
- Run focused tests for changed areas before broader test suites when possible.
- Always run `bin/rubocop --autocorrect` before committing any changes.

## Safety and Data Integrity
- Do not silently change persisted data semantics.
- If data format changes are required, include migration and model normalization.
- After adding or changing a DB migration (and after adding model tests or fixtures), run `bundle exec annotaterb models` and commit the refreshed schema annotations in models, tests, and fixtures. `db:migrate` only auto-annotates files that already exist at that moment.
- Validate external API payloads defensively.

## Bot Protection (Cloudflare Turnstile + Rack::Attack)
- Every publicly available form that accepts anonymous submissions must have BOTH layers of protection:
  1. Cloudflare Turnstile in the view (`render "shared/turnstile_widget"`) verified server-side via the `TurnstileVerifiable` concern (`before_action :verify_turnstile` on the submit action).
  2. Rack::Attack throttling for the submit path in `config/initializers/rack_attack.rb` (throttle by IP, and by email where the form accepts an email address).
- This currently covers: newsletter subscription, participant registration, magic-link sign-in, password sign-in (login), forgot-password, and resend-confirmation forms.
- When a public form maps to a Devise controller, add Turnstile by subclassing the Devise controller under `app/controllers/users/`, including `TurnstileVerifiable`, and wiring it through `devise_for ... controllers:`. For the sign-in (sessions) controller use `prepend_before_action :verify_turnstile` so the check runs before Devise's own authentication filters — otherwise Warden authenticates and persists the session before the check can halt the request.
- Add both protections to any new public form by default.

## Preference Update Rule (Important)
When the user expresses a new coding/UI/process preference in chat:
1. Apply the preference to the current task immediately.
2. Update this file (`AGENTS.md`) in the same work session so future agent runs follow it.
3. Keep the preference phrasing concise and actionable.
4. If a new preference conflicts with an existing one, replace the old rule and note the new default.

## Current User Preferences Captured
- Show clear unknown-email feedback on the forgot-password form; account enumeration is accepted for this flow.
- Keep participant date UX aligned with European day-before-month expectations.
- Keep portrait payment price tables compact enough for Euro amounts; show only the pass type in the participant payment summary, right-aligned.
- In mobile payment price tables, place each price-period “i” on its own right-aligned second header line.
- In portrait, shorten the participant details return link to “Back”, stack it with Edit, and stack admin Edit/Delete actions vertically.
- Use full strength labels: `kyu`, `dan`, `dan pro`.
- Show stronger playing strengths first.
- Country selector should support autocomplete with ISO alpha-2 semantics.
- Taiwan display name: `Chinese Taipei (Taiwan)`.
- Prefer standard Rails resource/controller naming; avoid custom controller names like `*ManagementController`.
- In the top bar, keep Newsletter and Register now CTAs green while reusing btn-primary for size and shape.
- In the top bar stacked-button layout (< lg), shorten `Register now` to `Register`.
- Mark mandatory form fields with a trailing asterisk in the label (e.g. `Email *`) consistently across all forms.
- On mobile, keep search as a top-level item in the menu bar, place the hamburger icon on the left, and make only the left half of the bar toggle the navigation panel.
- Cloudflare Turnstile is required on all publicly available submission forms, including Devise auth forms (login, forgot password, resend confirmation). Every public form must ALSO have Rack::Attack backend throttling (by IP, and by email where applicable). The two protections are complementary, not alternatives.
- For confirmation-email resends tied to a known record (e.g. a participant), use a backend route keyed by the record UUID rather than asking for or rendering the email address. Confirmation-link error forms may display the account email.
- Keep TinyMCE HTML sanitization liberal for stylistic formatting (colors, alignment, and border styling), while still blocking script/event-handler XSS vectors.
- When a signed-in (confirmed) user registers another participant, the email is pre-filled/locked to their own address; validate it matches, then confirm the participant immediately without sending a confirmation email and route straight to the next step (payment for players, participant page for visitors).
- When migrating participant confirmation to users, treat confirmation on either record as confirmed for both instead of blocking on mismatched statuses.
- In the participant Contact Information card, show the guest email explanation and existing-account warning full width below the field row.
- On phones, make the tournament schedule selectable by day and show a readable selected-day agenda; keep weekly calendar columns horizontally navigable.
- On mobile, only the blue menu/search bar stays sticky; keep the red brand header compact, with smaller buttons and logo in portrait.
- Keep event dates visible in the mobile header; in landscape, stack the dates beside a small logo and align the action buttons horizontally when space allows.
- Make date selection update the schedule directly without a separate submit button, and show event category colors in mobile agendas.
- Show the Fun Go explanation at the bottom of the desktop tournament schedule and in mobile agendas only on dates that include a Fun Go event; use a contextual “Back to events” link when editing calendar events.
- Keep the month calendar page removed; use the tournament schedule and day/week/list views instead.
- Reduce mobile page spacing above content and before the footer; keep the footer compact with a social row and responsive footer-link rows.
- In portrait mobile footer, put Privacy, Copyright, FAQ, and Contact on the top row; place Terms and Conditions alone on the second row, left-aligned with Privacy and kept on one line.
- Use lighter category-tinted backgrounds on mobile event tiles to improve event title and time readability.
- On the portrait My registrations page, use a compact plus button beside the title for registering another participant.
- In hostel bookings, show `Beds` (not `Guests`) in totals; in price calculation lines use the short labels `mixed dorm bed` / `female dorm bed` (full labels elsewhere) and keep each line on one row.
- In hostel booking forms, provide large, accessible increment and decrement buttons for room, bed, and breakfast quantities.
- Reprice hostel booking Products using the current HostelPricing tier when reviewing, checking out, or retrying an Order; pending Mollie attempts protect stored prices.
- Label the action that adds a provisional hostel booking to the basket “Book”; commitment to pay happens at basket checkout.
- Use `/newsletter` as the newsletter overview, with subscription in a modal; show editor/admin draft newsletters above sent issues and place Create newsletter above Subscribe.
- Make sent newsletter tiles fully clickable and include the count-confirmed Send action in both the editor and preview.
- Set newsletter email templates to a 1200px desktop maximum width and stack layout table cells on narrow screens.
- Require an email domain suffix without checking it against a list of valid extensions.
- Group admin overview links into themed cards for site content, financial matters, site structure, people, and communication; place hostel bookings under people.
- Preserve the originating article overview or article page for Back and Cancel links when viewing or editing news articles.

- Use `Order.has_many :products` for multiple Products per Order; do not add a duplicate singular product association.
- Visitors do not require participant tickets, products, or orders; preserve existing payment history when participant type changes.
- Store attendance periods on participants, including visitors; participant tickets belong to players and have a price.
- Keep the congress ticket price current until a payment attempt starts; replacement attempts use the current price tier.
- Keep successful payments paid after refunds or chargebacks; their orders remain closed and any new payment requires a new order.
- In admin financial overviews, keep payer/user columns compact with linked names, provide sortable headers and status filters where relevant, and format dates as `dd/mm/yyyy HH:MM`.
- In Admin Payments date sorting, use the displayed payment date first, then the full Payment `created_at` timestamp, then Payment ID.
- Show the Admin Orders status filter as a collapsible checkbox menu; apply multiple selections with an explicit Filter button and collapse it after submission.
- In My Participants, show each participant ticket's Order payment status with the shared status colors, and label Visitors in green.
- Route participant ticket payments through their Order; show pending Order links instead of a duplicate Pay action, and use green/gray/red/blue indicators for paid/pending/failed/awaiting Order statuses.
- Keep submitted Order summaries within the available row width by truncating long Product descriptions with ellipses, and sort Products by type then addition order in Order lists and details.
- Label a cancelled Order “Order canceled” to distinguish it from a cancelled Payment.
- In the admin Payments overview, list all Payment statuses; sort Date, Order ID, Amount, and Payer; filter by Method; link Payment and Order IDs to their admin detail pages.
- Show the shopping basket icon and Product count beside the User menu on desktop and left of search in the mobile menu bar; use “Add <product>” for empty sections and “Add another <product>” for populated sections, with lower-case product display names. In basket rows, right-align prices and use accessible icon-only Edit/Remove actions. Show ticket discounts and use singular “breakfast” when the count is one; place the destructive empty-basket button at the bottom right.
- In basket participant ticket edit forms, clearly outline editable text fields and dropdowns, and make the entire dropdown clickable to open it.
- Keep the basket checkout button label centered and allow it to wrap within the button on narrow screens.
- Keep the mobile basket count badge clear of the top edge of the menu bar.
- After a new participant confirms their email and sets or skips a password, take them to their shopping basket when it contains a participant ticket.
- In the Admin Add payment form, display the full Order amount without an editable field, keep the form on an opaque background, and omit the payment receipt explanation.
- Hide Add payment for Orders with an active payment; in the Admin Orders overview, use matching compact buttons for Add payment and Cancel order.
- In the Admin Add payment Order summary, place a divider below the products and above the total; reject future manual payment dates with a clear error.
- Reuse shared Shopping Basket partials and participant forms for Admin Orders; place a searchable owner selector at the top right, and confirm owner changes before clearing products. New Admin-registered participants belong to the selected Order owner (superseding the earlier Admin-owned default).
- Use autocomplete dropdowns for Admin participant selection. All participant tickets must belong to participants owned by the Order's User, including Admin-created Orders (superseding the temporary Admin-owned exception). When selecting another user's participant, offer Change owner (add the ticket and return to the basket) or Cancel (return to participant selection); do not offer Keep owner.
- Make Admin owner selection a typable dropdown with a blank filter on opening and immediate saving on selection; title existing baskets "Shopping Basket for Order <id>". For existing unpaid tickets, advise paying or canceling the linked Orders while keeping the current basket open.
- Explain draft conflicts as "<user name> already has a draft order. This order needs to be completed before a new order in their name can be processed." and link that Order in the same message. Offer Admin draft deletion from the basket, Order details and draft overview, including empty drafts.
- Do not persist empty User draft Orders when viewing or prefetching the basket or participant selection; create drafts when adding Products, and do not automatically replace submitted Orders.
- When Admins follow an unpaid-ticket Order link from a draft basket, return to that draft's participant selection after canceling the unpaid Order or deleting its draft.
- Exclude participants already in the current Admin draft from participant autocomplete; repeated additions should explain they are already in this basket without a conflicting unpaid-Order warning.
- For Admin Order cancellation, show the Order ID and nonzero counts of participant tickets and hostel bookings, explain that participant registrations are kept, and label the choices “OK” and “Do not cancel”.
- Display all date selectors in dd/mm/yyyy format, including date-time forms and date dropdowns; keep calendar selection available and submit unambiguous dates.
- In Admin Orders, label the draft section “Orders still in draft”, group filters within “Submitted Orders”, and preserve sorting and status filters when returning from Order details.
- On the Admin Orders overview, show Orders still in draft as a collapsed disclosure with the same heading size as Deleted draft Orders.

- Derive Participant status from User confirmation and valid paid tickets; keep refund and cancellation statuses as Admin-controlled overrides independent of financial records.
- Label participant status columns “Participant status”; in the Admin participants overview show a separate ticket payment status, shorten “Participation canceled” to “Canceled”, and stack participant actions vertically and outline the Add payment button.
- Show the effective participant status with the shared colored badge on the Admin participant edit form.
- In Admin participants, use collapsible checkbox filters for participant and payment status, preserve all overview filters and sorting when returning from participant or payment editing, use compact rectangular badges, and right-align the stacked actions.
- Public participant lists include only effective statuses user_confirmed and paid; My registrations displays participant statuses as Unconfirmed, No paid ticket, Paid ticket, Awaiting refund, Refunded ticket, and Canceled.
- In My registrations, place Participant status before Payment status.

- When displaying a player's payment status without a current ticket, show the latest canceled ticket Order if one exists; keep this fallback separate from admission and purchase eligibility.
- Make each Admin Payments overview row clickable to open its Payment detail, while preserving links to related records.
- On Admin Payment details, label the return link “Back to payments” and preserve overview sorting and filtering when arriving from the overview.
- In Admin Payments, show payment status using shared status colors and offer a Not paid filter covering every non-paid status.
- Make Admin participant overview rows clickable; show the registering User on participant details and identify each Order’s ticket in parentheses.
- On Admin Order details, link each participant ticket and participant name to their respective detail pages.
- On Admin Order details, show participant age group beside ticket attendance using the shopping basket format.

- Show hostel booking payment and Order cancellation statuses separately, with linked details and preserved overview filters.
- Close filter dropdowns when clicking outside; use a direct single-select filter for hostel Order status.
- On hostel booking details, avoid repeating accommodation line items already shown in the price calculation.
- Link hostel booking product names to their detail pages on Order details, showing the booking ID prefixed with #.
- In hostel booking details, show Order status only when canceled, with bold red text; omit participants in the Order and payment section.
- Show canceled Order status badges in red on user and admin Order detail pages, matching canceled payments.

- In Admin participant views, use the simplified participant and payment status labels and filters; keep user-facing status labels independent.
- On Admin participant details, show Order and Ticket links; access Payments through the Order.
- On Admin ticket details, show attendance, age group, discount, payment date and the pricing period inferred from that date; distinguish current participant details from historical pricing.
- On Admin ParticipantTicket details, display invalid admission in bold red.
