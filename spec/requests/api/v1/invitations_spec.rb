# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  def jwt_token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  path "/api/v1/invitations" do
    get "List all invitations" do
      tags "Invitations"
      description "Retrieve a paginated list of all invitations. Only available to librarians."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      parameter name: :page,
                in: :query,
                type: :integer,
                required: false,
                description: "Page number (default: 1)"

      parameter name: :per_page,
                in: :query,
                type: :integer,
                required: false,
                description: "Number of items per page (default: 25, max: 100)"

      parameter name: "page[number]",
                in: :query,
                type: :integer,
                required: false,
                description: "Page number (JSON:API style)"

      parameter name: "page[size]",
                in: :query,
                type: :integer,
                required: false,
                description: "Page size (JSON:API style)"

      response "200", "Invitations retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, example: "invitations" },
                       attributes: {
                         type: :object,
                         properties: {
                           email: { type: :string },
                           role: { type: :string },
                           expires_at: { type: :string, format: "date-time" },
                           accepted_at: { type: :string, format: "date-time", nullable: true },
                           status: { type: :string, enum: %w[pending accepted expired] },
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
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     page: {
                       type: :object,
                       properties: {
                         total: { type: :integer },
                         totalPages: { type: :integer },
                         number: { type: :integer },
                         size: { type: :integer }
                       }
                     }
                   }
                 },
                 links: {
                   type: :object,
                   properties: {
                     self: { type: :string },
                     first: { type: :string },
                     last: { type: :string },
                     prev: { type: :string, nullable: true },
                     next: { type: :string, nullable: true }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }

        before { create_list(:invitation, 3, invited_by: librarian) }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"].size).to eq(3)
          expect(json_response["data"].first).to have_key("type")
          expect(json_response["data"].first["type"]).to eq("invitations")
          expect(json_response["meta"]["page"]).to include(
            "total" => 3,
            "totalPages" => 1,
            "number" => 1,
            "size" => 25
          )
          expect(json_response["links"]).to have_key("self")
          expect(json_response["links"]).to have_key("first")
        end
      end

      response "200", "Returns invitation attributes correctly" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }

        before do
          create(:invitation, email: "test@example.com", role: "librarian", invited_by: librarian)
        end

        run_test! do |response|
          invitation_data = json_response["data"].first
          expect(invitation_data["attributes"]["email"]).to eq("test@example.com")
          expect(invitation_data["attributes"]["role"]).to eq("librarian")
          expect(invitation_data["attributes"]["status"]).to eq("pending")
          expect(invitation_data["attributes"]).to have_key("expires_at")
          expect(invitation_data["attributes"]).to have_key("created_at")
          expect(invitation_data["relationships"]["invited_by"]["data"]["id"]).to eq(librarian.id.to_s)
        end
      end

      response "200", "Returns paginated results" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }

        before { create_list(:invitation, 30, invited_by: librarian) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(25)
          expect(json_response["meta"]["page"]["total"]).to eq(30)
          expect(json_response["meta"]["page"]["totalPages"]).to eq(2)
          expect(json_response["meta"]["page"]["number"]).to eq(1)
          expect(CGI.unescape(json_response["links"]["next"])).to include("page[number]=2")
        end
      end

      response "200", "Orders invitations by created_at desc" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let!(:oldest) { create(:invitation, invited_by: librarian, created_at: 3.days.ago) }
        let!(:newest) { create(:invitation, invited_by: librarian, created_at: 1.day.ago) }
        let!(:middle) { create(:invitation, invited_by: librarian, created_at: 2.days.ago) }

        run_test! do |response|
          ids = json_response["data"].map { |inv| inv["id"].to_i }
          expect(ids).to eq([ newest.id, middle.id, oldest.id ])
        end
      end

      response "403", "Member cannot list invitations" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }

        run_test! do |response|
          expect(response.status).to eq(403)
        end
      end

      response "401", "Requires authentication" do
        let(:Authorization) { "" }

        run_test!
      end
    end

    post "Create invitation" do
      tags "Invitations"
      description "Create a new invitation to invite a librarian to join the system."
      consumes "application/json"
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      parameter name: :invitation,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    invitation: {
                      type: :object,
                      properties: {
                        email: { type: :string, format: :email }
                      },
                      required: [ "email" ]
                    }
                  },
                  required: [ "invitation" ]
                }

      response "201", "Invitation created successfully" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:invitation) { { invitation: { email: "newuser@example.com" } } }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["email"]).to eq("newuser@example.com")
          expect(json_response["data"]["attributes"]["role"]).to eq("librarian")
          expect(json_response["data"]["attributes"]["status"]).to eq("pending")
          expect(json_response["data"]["attributes"]).to have_key("token")
        end
      end

      response "403", "Member cannot create invitations" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:invitation) { { invitation: { email: "test@example.com" } } }

        run_test!
      end

      response "422", "Invalid email format" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:invitation) { { invitation: { email: "invalid-email" } } }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "400", "Email is required" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:invitation) { { invitation: { email: "" } } }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end
    end
  end

  path "/api/v1/invitations/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "Invitation ID"

    get "Show invitation" do
      tags "Invitations"
      description "Retrieve details of a specific invitation. Only available to librarians."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

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
                         expires_at: { type: :string, format: "date-time" },
                         accepted_at: { type: :string, format: "date-time", nullable: true },
                         status: { type: :string },
                         created_at: { type: :string, format: "date-time" }
                       }
                     },
                     relationships: { type: :object }
                   }
                 },
                 meta: { type: :object }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let!(:invitation_record) { create(:invitation, email: "show@example.com", invited_by: librarian) }
        let(:id) { invitation_record.id }

        run_test! do |response|
          expect(json_response["data"]["id"]).to eq(invitation_record.id.to_s)
          expect(json_response["data"]["attributes"]["email"]).to eq("show@example.com")
          expect(json_response["data"]["attributes"]["status"]).to eq("pending")
        end
      end

      response "403", "Member cannot view invitations" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let!(:invitation_record) { create(:invitation, invited_by: librarian) }
        let(:id) { invitation_record.id }

        run_test!
      end

      response "404", "Invitation not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { 999999 }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["status"]).to eq("404")
        end
      end
    end

    delete "Delete invitation" do
      tags "Invitations"
      description "Cancel a pending invitation. Only available to librarians. Cannot delete accepted or expired invitations."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      response "204", "Invitation deleted successfully" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let!(:invitation_record) { create(:invitation, invited_by: librarian) }
        let(:id) { invitation_record.id }

        run_test! do |response|
          expect(response.status).to eq(204)
          expect(Invitation.find_by(id: invitation_record.id)).to be_nil
        end
      end

      response "403", "Member cannot delete invitations" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let!(:invitation_record) { create(:invitation, invited_by: librarian) }
        let(:id) { invitation_record.id }

        run_test!
      end

      response "403", "Cannot delete accepted invitation (policy check)" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let!(:invitation_record) { create(:invitation, :accepted, invited_by: librarian) }
        let(:id) { invitation_record.id }

        run_test! do |response|
          expect(response.status).to eq(403)
        end
      end

      response "403", "Cannot delete expired invitation (policy check)" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let!(:invitation_record) { create(:invitation, :expired, invited_by: librarian) }
        let(:id) { invitation_record.id }

        run_test! do |response|
          expect(response.status).to eq(403)
        end
      end

      response "404", "Invitation not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { 999999 }

        run_test!
      end
    end
  end

  path "/api/v1/invitations/token/{token}" do
    parameter name: :token, in: :path, type: :string, description: "Invitation token"

    get "Show invitation by token" do
      tags "Invitations"
      description "Retrieve invitation details using a token. No authentication required. Public endpoint for invitation recipients."
      produces "application/vnd.api+json"

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
                         expires_at: { type: :string, format: "date-time" },
                         accepted_at: { type: :string, format: "date-time", nullable: true },
                         status: { type: :string }
                       }
                     },
                     relationships: { type: :object }
                   }
                 },
                 meta: { type: :object }
               }

        let!(:invitation_record) { create(:invitation, email: "token@example.com", invited_by: librarian) }
        let(:token) { invitation_record.token }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["email"]).to eq("token@example.com")
          expect(json_response["data"]["attributes"]["status"]).to eq("pending")
          # Public view should not expose created_at or invited_by
          expect(json_response["data"]["attributes"]).not_to have_key("created_at")
          # Relationships exist but should be empty (no invited_by in public view)
          expect(json_response["data"]["relationships"]).to eq({})
        end
      end

      response "200", "Shows expired invitation status" do
        let!(:invitation_record) { create(:invitation, :expired, email: "expired@example.com", invited_by: librarian) }
        let(:token) { invitation_record.token }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["email"]).to eq("expired@example.com")
          expect(json_response["data"]["attributes"]["status"]).to eq("expired")
          expect(json_response["data"]["attributes"]["accepted_at"]).to be_nil
          # Public view should not expose internal details
          expect(json_response["data"]["attributes"]).not_to have_key("created_at")
          expect(json_response["data"]["relationships"]).to eq({})
        end
      end

      response "200", "Shows accepted invitation status" do
        let!(:invitation_record) { create(:invitation, :accepted, email: "accepted@example.com", invited_by: librarian) }
        let(:token) { invitation_record.token }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["email"]).to eq("accepted@example.com")
          expect(json_response["data"]["attributes"]["status"]).to eq("accepted")
          expect(json_response["data"]["attributes"]["accepted_at"]).to be_present
          # Public view should not expose internal details
          expect(json_response["data"]["attributes"]).not_to have_key("created_at")
          expect(json_response["data"]["relationships"]).to eq({})
        end
      end

      response "200", "Hides sensitive data in public view" do
        let!(:invitation_record) { create(:invitation, email: "public@example.com", invited_by: librarian) }
        let(:token) { invitation_record.token }

        run_test! do |response|
          # Verify public_view parameter is working correctly
          expect(json_response["data"]["attributes"]).not_to have_key("created_at")
          expect(json_response["data"]["attributes"]).not_to have_key("token")
          expect(json_response["data"]["relationships"]).to eq({})
          # But should still show essential info
          expect(json_response["data"]["attributes"]["email"]).to eq("public@example.com")
          expect(json_response["data"]["attributes"]["role"]).to eq("librarian")
          expect(json_response["data"]["attributes"]["expires_at"]).to be_present
        end
      end

      response "404", "Invalid token" do
        let(:token) { "invalid-token-123" }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["status"]).to eq("404")
        end
      end
    end
  end

  path "/api/v1/invitations/token/{token}/accept" do
    parameter name: :token, in: :path, type: :string, description: "Invitation token"

    patch "Accept invitation" do
      tags "Invitations"
      description "Accept an invitation and create a new user account. No authentication required."
      consumes "application/json"
      produces "application/vnd.api+json"

      parameter name: :user,
                in: :body,
                schema: {
                  type: :object,
                  properties: {
                    user: {
                      type: :object,
                      properties: {
                        name: { type: :string },
                        password: { type: :string, format: :password },
                        password_confirmation: { type: :string, format: :password }
                      },
                      required: %w[name password password_confirmation]
                    }
                  },
                  required: [ "user" ]
                }

      response "201", "Account created successfully" do
        let!(:invitation_record) { create(:invitation, email: "accept@example.com", invited_by: librarian) }
        let(:token) { invitation_record.token }
        let(:user) do
          {
            user: {
              name: "New Librarian",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end

        run_test! do |response|
          expect(json_response["data"]["attributes"]["email"]).to eq("accept@example.com")
          expect(json_response["data"]["attributes"]["name"]).to eq("New Librarian")
          expect(json_response["data"]["attributes"]["role"]).to eq("librarian")

          # Verify invitation is now accepted
          invitation_record.reload
          expect(invitation_record.accepted?).to be true

          # Verify user was created
          created_user = User.find_by(email: "accept@example.com")
          expect(created_user).to be_present
          expect(created_user.name).to eq("New Librarian")
        end
      end

      response "410", "Invitation expired" do
        let!(:invitation_record) { create(:invitation, :expired, invited_by: librarian) }
        let(:token) { invitation_record.token }
        let(:user) do
          {
            user: {
              name: "Test User",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["detail"]).to include("expired")
        end
      end

      response "410", "Invitation already accepted" do
        let!(:invitation_record) { create(:invitation, :accepted, invited_by: librarian) }
        let(:token) { invitation_record.token }
        let(:user) do
          {
            user: {
              name: "Test User",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["detail"]).to include("already been used")
        end
      end

      response "422", "Invalid user data" do
        let!(:invitation_record) { create(:invitation, invited_by: librarian) }
        let(:token) { invitation_record.token }
        let(:user) do
          {
            user: {
              name: "",
              password: "short",
              password_confirmation: "short"
            }
          }
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "404", "Invalid token" do
        let(:token) { "invalid-token-123" }
        let(:user) do
          {
            user: {
              name: "Test User",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end
    end
  end
end
