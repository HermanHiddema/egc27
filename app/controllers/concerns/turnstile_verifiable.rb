module TurnstileVerifiable
  extend ActiveSupport::Concern

  private

  def verify_turnstile
    token = params["cf-turnstile-response"]
    return if CloudflareTurnstileService.new.verify(token: token, remote_ip: request.remote_ip)

    flash.now[:alert] = "CAPTCHA verification failed. Please try again."
    render turnstile_failure_template, status: :unprocessable_entity
  end

  # Override in controllers that use a template name other than :new for the form view.
  def turnstile_failure_template
    :new
  end
end
