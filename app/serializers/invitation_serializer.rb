# frozen_string_literal: true

class InvitationSerializer
  include JSONAPI::Serializer

  set_type :invitations

  attributes :email, :role, :expires_at, :accepted_at

  attribute :token, if: proc { |_record, params| params && params[:include_token] }

  attribute :status do |invitation|
    if invitation.accepted?
      "accepted"
    elsif invitation.expired?
      "expired"
    else
      "pending"
    end
  end

  attribute :created_at, if: proc { |_record, params| !params || !params[:public_view] }

  belongs_to :invited_by, serializer: UserSerializer, if: proc { |_record, params| !params || !params[:public_view] }
end
