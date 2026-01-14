# frozen_string_literal: true

module Api
  module V1
    class SessionsController < Devise::SessionsController
      include JsonapiResponse

      respond_to :json

      def create
        response = Authentication::LoginService.new(params: login_params).call

        if response.success?
          sign_in(:user, response.data, store: false)
          render_service_success(response, serializer: UserSerializer)
        else
          render_service_failure(response)
        end
      end

      private

      def respond_to_on_destroy
        if request.headers["Authorization"].present?
          render json: {
            meta: { message: "Logged out successfully." }
          }, status: :ok
        else
          render json: {
            errors: [
              {
                status: "401",
                title: "Unauthorized",
                detail: "No active session."
              }
            ]
          }, status: :unauthorized
        end
      end

      def login_params
        params.require(:user).permit(:email, :password).to_h.symbolize_keys
      end
    end
  end
end
