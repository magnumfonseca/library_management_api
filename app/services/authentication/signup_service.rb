# frozen_string_literal: true

module Authentication
  class SignupService
    def initialize(params:)
      @params = params
    end

    def call
      user = User.new(user_params)

      if user.save
        Response.success(user, meta: { message: "Signed up successfully." })
      else
        Response.failure(user.errors.full_messages)
      end
    end

    private

    def user_params
      @params.slice(:email, :password, :password_confirmation, :name)
    end
  end
end
