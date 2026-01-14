# frozen_string_literal: true

module Authentication
  class LoginService
    def initialize(params:)
      @email = params[:email]
      @password = params[:password]
    end

    def call
      return Response.failure("Email and password are required.", http_status: :bad_request) if missing_credentials?

      user = User.find_by(email: @email)

      return Response.failure("Invalid email or password.", http_status: :unauthorized) unless user
      return forbidden_response(user) unless user.active_for_authentication?
      return Response.failure("Invalid email or password.", http_status: :unauthorized) unless user.valid_password?(@password)

      Response.success(user, meta: { message: "Logged in successfully." })
    end

    private

    def missing_credentials?
      @email.blank? || @password.blank?
    end

    def forbidden_response(user)
      Response.failure(message_for_inactive_user(user), http_status: :forbidden)
    end

    def message_for_inactive_user(user)
      case user.inactive_message
      when :unconfirmed
        "Please confirm your email address before signing in."
      when :locked
        "Your account has been locked. Please contact support."
      else
        "Your account is not active."
      end
    end
  end
end
