# frozen_string_literal: true

class InvitationSerializer
  def initialize(invitation, include_token: false)
    @invitation = invitation
    @include_token = include_token
  end

  def as_jsonapi
    {
      data: {
        type: "invitations",
        id: @invitation.id.to_s,
        attributes: {
          email: @invitation.email,
          role: @invitation.role,
          token: @include_token ? @invitation.token : nil,
          expires_at: @invitation.expires_at,
          accepted_at: @invitation.accepted_at
        },
        relationships: {
          invited_by: {
            data: {
              type: "users",
              id: @invitation.invited_by_id.to_s
            }
          }
        }
      }
    }
  end

  def self.collection(invitations)
    {
      data: invitations.map { |invitation| new(invitation).as_jsonapi[:data] }
    }
  end
end
