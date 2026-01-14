# frozen_string_literal: true

module Invitations
  class AcceptService
    def initialize(token:, params:)
      @token = token
      @params = params
    end

    def call
      return Response.failure("Invitation token is required.", http_status: :bad_request) if @token.blank?

      invitation = Invitation.find_by(token: @token)

      return Response.failure("Invalid invitation token.", http_status: :not_found) unless invitation
      return Response.failure("This invitation has expired.", http_status: :gone) if invitation.expired?
      return Response.failure("This invitation has already been used.", http_status: :gone) if invitation.accepted?

      user = invitation.build_user(@params)

      ActiveRecord::Base.transaction do
        if user.save
          invitation.accept!
          Response.success(user, meta: { message: "Account created successfully." })
        else
          Response.failure(user.errors.full_messages)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Response.failure(e.record.errors.full_messages)
    end
  end
end
