module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :fitness_session
  ERROR_CODE_UNAUTHORIZED = "unauthorized"

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def require_authentication
    Current.user = authenticate_with_bearer_token || authenticate_with_session_cookie
    return if Current.user

    render_api_error(
      field: "base",
      code: ERROR_CODE_UNAUTHORIZED,
      message: "Authentication required",
      status: :unauthorized
    )
  end

  def authenticate_with_bearer_token
    scheme, token = request.authorization.to_s.split(" ", 2)
    return unless scheme&.casecmp?("Bearer")

    ApiToken.authenticate(token)
  end

  def authenticate_with_session_cookie
    session_id = cookies.encrypted[SESSION_COOKIE]
    return if session_id.blank?

    Current.session = Session.includes(:user).find_by(id: session_id)
    Current.session&.user
  end

  def start_session_for(user)
    session = user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    cookies.encrypted.permanent[SESSION_COOKIE] = {
      value: session.id,
      httponly: true,
      same_site: :strict,
      secure: Rails.env.production?
    }
    Current.session = session
    Current.user = user
  end

  def end_current_session
    Current.session&.destroy!
    cookies.delete(
      SESSION_COOKIE,
      httponly: true,
      same_site: :strict,
      secure: Rails.env.production?
    )
    Current.reset
  end
end
