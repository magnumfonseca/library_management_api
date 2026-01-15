# frozen_string_literal: true

module Api
  module V1
    class InvitationsController < ApplicationController
      include JsonapiResponse

      skip_before_action :authenticate_user!, only: [ :accept ]

      def create
        authorize Invitation
        response = Invitations::CreateService.new(
          params: invitation_params,
          current_user: current_user
        ).call

        if response.success?
          render_service_success(response, serializer: InvitationSerializer,
                                params: { include_token: true }, status: :created)
        else
          render_service_failure(response)
        end
      end

      def accept
        response = Invitations::AcceptService.new(
          token: params[:token],
          params: accept_params
        ).call

        if response.success?
          sign_in(:user, response.data, store: false)
          render_service_success(response, serializer: UserSerializer, status: :created)
        else
          render_service_failure(response)
        end
      end

      private

      def invitation_params
        params.require(:invitation).permit(:email)
      end

      def accept_params
        params.require(:user).permit(:name, :password, :password_confirmation)
      end
    end
  end
end
