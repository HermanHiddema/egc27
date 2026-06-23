module Users
  # Custom Devise mailer. Inherits from the passwordless mailer so magic-link
  # delivery keeps working, while letting us send a tailored confirmation email
  # for accounts auto-created during participant registration.
  class Mailer < Devise::Passwordless::Mailer
    def confirmation_instructions(record, token, opts = {})
      participant = record.registration_participant
      if participant.present?
        @participant = participant
        opts[:subject] = "EGC 2027 – Confirm your account"
        opts[:template_name] = "registration_confirmation_instructions"
      end

      super
    end
  end
end
