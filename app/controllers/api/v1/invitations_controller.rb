# frozen_string_literal: true

module Api
  module V1
    class InvitationsController < ApplicationController
      include JsonapiResponse
      include Paginatable

      skip_before_action :authenticate_user!, only: [ :accept, :show_by_token ]
      skip_after_action :verify_authorized, only: [ :accept, :show_by_token ]

      before_action :set_invitation, only: [ :show, :destroy ]
      before_action :set_invitation_by_token, only: [ :accept, :show_by_token ]

      def index
        authorize Invitation
        invitations = policy_scope(Invitation).includes(:invited_by).order(created_at: :desc)
        render_paginated_collection(invitations, serializer: InvitationSerializer)
      end

      def show
        authorize @invitation
        render_record(@invitation, serializer: InvitationSerializer)
      end

      def show_by_token
        render_record(@invitation, serializer: InvitationSerializer, params: { public_view: true })
      end

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

      def destroy
        authorize @invitation
        response = Invitations::DeleteService.new(
          invitation: @invitation
        ).call

        if response.success?
          head :no_content
        else
          render_service_failure(response)
        end
      end

      def accept
        response = Invitations::AcceptService.new(
          invitation: @invitation,
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

      def set_invitation
        @invitation = Invitation.includes(:invited_by).find(params[:id])
      end

      def set_invitation_by_token
        @invitation = Invitation.find_by!(token: params[:token])
      rescue ActiveRecord::RecordNotFound
        raise ActiveRecord::RecordNotFound, "Invalid invitation token"
      end

      def invitation_params
        params.require(:invitation).permit(:email)
      end

      def accept_params
        params.require(:user).permit(:name, :password, :password_confirmation)
      end
    end
  end
end
