# frozen_string_literal: true

module Invitations
  class CreateService
    def initialize(params:, current_user:)
      @email = params[:email]
      @role = params[:role] || "librarian"
      @current_user = current_user
    end

    def call
      return Response.failure("Email is required.", http_status: :bad_request) if @email.blank?
      return Response.failure("A user with this email already exists.", http_status: :unprocessable_content) if User.exists?(email: @email)
      return Response.failure("An invitation for this email is already pending.", http_status: :unprocessable_content) if pending_invitation_exists?

      invitation = build_invitation

      if invitation.save
        Response.success(invitation, meta: { message: "Invitation sent successfully." })
      else
        Response.failure(invitation.errors.full_messages)
      end
    end

    private

    def build_invitation
      Invitation.new(
        email: @email,
        role: @role,
        invited_by: @current_user
      )
    end

    def pending_invitation_exists?
      Invitation.pending.exists?(email: @email)
    end
  end
end
