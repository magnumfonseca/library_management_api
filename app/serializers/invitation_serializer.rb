# frozen_string_literal: true

class InvitationSerializer
  include JSONAPI::Serializer

  set_type :invitations

  attributes :email, :role, :expires_at, :accepted_at

  attribute :token, if: proc { |_record, params| params && params[:include_token] }

  belongs_to :invited_by, serializer: UserSerializer
end
