# frozen_string_literal: true

module Invitations
  # Service to cancel/delete pending invitations
  # Note: This service includes defensive checks that duplicate policy validations.
  # This is intentional to ensure service can be safely called from any context
  # (tests, console, background jobs) where policy authorization might be bypassed.
  class DeleteService
    def initialize(invitation:)
      @invitation = invitation
    end

    def call
      return Response.failure("Invitation not found.", http_status: :not_found) if @invitation.nil?
      return Response.failure("Cannot cancel an accepted invitation.", http_status: :unprocessable_content) if @invitation.accepted?
      return Response.failure("Cannot cancel an expired invitation.", http_status: :unprocessable_content) if @invitation.expired?

      @invitation.destroy!
      Response.success(nil, meta: { message: "Invitation cancelled successfully." })
    rescue ActiveRecord::RecordNotDestroyed
      Response.failure("Failed to cancel invitation.", http_status: :unprocessable_content)
    end
  end
end
