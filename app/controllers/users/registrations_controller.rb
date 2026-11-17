module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :require_authenticated_user, only: [:skip_password]

    # Newly confirmed users can skip setting a password and sign in later by
    # requesting a magic link to their email.
    def skip_password
      destination = confirmed_registration_with_ticket?(current_user) ? order_path : mine_participants_path
      redirect_to destination,
        notice: "No problem — you can sign in any time by requesting a magic link to your email."
    end

    protected

    def update_resource(resource, params)
      # For users without a password (newly confirmed), don't require current password
      if resource.password_set?
        super
      else
        # Skip current_password validation for users without a password
        sanitized_params = params.dup
        sanitized_params.delete(:current_password)
        resource.update(sanitized_params)
      end
    end

    def after_update_path_for(resource)
      return order_path if confirmed_registration_with_ticket?(resource)

      super
    end

    private

    def confirmed_registration_with_ticket?(user)
      return false unless session.delete(:confirmed_registration_user_id) == user.id

      user.orders.drafts.joins(:products).where(products: { productable_type: ParticipantTicket.polymorphic_name }).exists?
    end

    # Wraps authenticate_user! under a distinct filter name on purpose: declaring
    # `before_action :authenticate_user!` here would re-register the same callback
    # ApplicationController already defines and override its options for this
    # controller, so we use a dedicated method to keep the existing chain intact.
    def require_authenticated_user
      authenticate_user!
    end
  end
end
