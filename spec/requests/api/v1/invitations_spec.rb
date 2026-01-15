# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let(:librarian) { create(:user, :librarian) }

  path "/api/v1/invitations/token/{token}" do
    parameter name: :token, in: :path, type: :string, required: true, description: "Invitation token"

    get "Get invitation by token" do
      tags "Invitations"
      description "Retrieve invitation details using a token. This is a public endpoint that doesn't require authentication."
      produces "application/vnd.api+json"

      let!(:invitation) { create(:invitation, invited_by: librarian) }

      response "200", "Invitation retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "invitations" },
                     attributes: {
                       type: :object,
                       properties: {
                         email: { type: :string },
                         role: { type: :string },
                         expires_at: { type: :string },
                         accepted_at: { type: :string, nullable: true },
                         status: { type: :string }
                       },
                       required: %w[email role expires_at status]
                     },
                     relationships: {
                       type: :object,
                       additionalProperties: true
                     }
                   }
                 },
                 meta: { type: :object }
               }

        let(:token) { invitation.token }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["type"]).to eq("invitations")
          expect(json_response["data"]["id"]).to eq(invitation.id.to_s)
          expect(json_response["data"]["attributes"]["email"]).to eq(invitation.email)
          expect(json_response["data"]["attributes"]["role"]).to eq(invitation.role)
          expect(json_response["data"]["attributes"]["status"]).to eq("pending")
        end
      end

      response "200", "Public view excludes created_at and invited_by relationship data" do
        let(:token) { invitation.token }

        run_test! do |response|
          expect(json_response["data"]["attributes"]).not_to have_key("created_at")
          # The invited_by relationship should either be absent or not include data when public_view is true
          if json_response["data"].key?("relationships")
            expect(json_response["data"]["relationships"]).not_to have_key("invited_by")
          end
        end
      end

      response "200", "Returns correct status for expired invitation" do
        let!(:expired_invitation) { create(:invitation, :expired, invited_by: librarian) }
        let(:token) { expired_invitation.token }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["status"]).to eq("expired")
          expect(json_response["data"]["attributes"]["email"]).to eq(expired_invitation.email)
        end
      end

      response "200", "Returns correct status for accepted invitation" do
        let!(:accepted_invitation) { create(:invitation, :accepted, invited_by: librarian) }
        let(:token) { accepted_invitation.token }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["status"]).to eq("accepted")
          expect(json_response["data"]["attributes"]["accepted_at"]).to be_present
        end
      end

      response "404", "Invalid token" do
        let(:token) { "invalid-token-that-does-not-exist" }

        run_test! do |response|
          expect(json_response).to have_key("errors")
          expect(json_response["errors"].first["status"]).to eq("404")
          expect(json_response["errors"].first["detail"]).to eq("Invalid invitation token")
        end
      end
    end
  end
end
