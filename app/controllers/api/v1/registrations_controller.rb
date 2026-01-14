# frozen_string_literal: true

module Api
  module V1
    class RegistrationsController < Devise::RegistrationsController
      include JsonapiResponse

      respond_to :json

      def create
        response = Authentication::SignupService.new(params: sign_up_params.to_h).call

        if response.success?
          sign_in(:user, response.data, store: false)
          render_service_success(response, serializer: UserSerializer, status: :created)
        else
          render_service_failure(response)
        end
      end

      private

      def sign_up_params
        params.require(:user).permit(:email, :password, :password_confirmation, :name)
      end
    end
  end
end
