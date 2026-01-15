# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  def jwt_token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  path "/api/v1/invitations/{id}" do
    parameter name: :id, in: :path, type: :string, required: true, description: "Invitation ID"

    get "Get invitation details" do
      tags "Invitations"
      description "Retrieve detailed information about a specific invitation. Only accessible by librarians."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

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
                         status: { type: :string },
                         expires_at: { type: :string, format: "date-time" },
                         accepted_at: { type: :string, format: "date-time", nullable: true },
                         created_at: { type: :string, format: "date-time" }
                       }
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         invited_by: {
                           type: :object,
                           properties: {
                             data: {
                               type: :object,
                               properties: {
                                 id: { type: :string },
                                 type: { type: :string, example: "users" }
                               }
                             }
                           }
                         }
                       }
                     }
                   }
                 },
                 meta: { type: :object }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { invitation.id }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["type"]).to eq("invitations")
          expect(json_response["data"]["id"]).to eq(invitation.id.to_s)
          expect(json_response["data"]["attributes"]["email"]).to eq(invitation.email)
          expect(json_response["data"]["attributes"]["status"]).to eq("pending")
        end
      end

      response "403", "Forbidden - Member cannot view invitations" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { invitation.id }

        run_test! do |response|
          expect(json_response).to have_key("errors")
          expect(json_response["errors"].first["status"]).to eq("403")
        end
      end

      response "404", "Invitation not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { 999999 }

        run_test! do |response|
          expect(json_response).to have_key("errors")
          expect(json_response["errors"].first["status"]).to eq("404")
        end
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { invitation.id }

        run_test!
      end
    end
  end
end
