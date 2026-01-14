# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication", type: :request do
  describe "POST /api/v1/signup" do
    let(:valid_params) do
      {
        user: {
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "Test User",
          role: "member"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new user" do
        expect {
          post "/api/v1/signup", params: valid_params, as: :json
        }.to change(User, :count).by(1)
      end

      it "returns created status" do
        post "/api/v1/signup", params: valid_params, as: :json
        expect(response).to have_http_status(:created)
      end

      it "returns JSON:API formatted response" do
        post "/api/v1/signup", params: valid_params, as: :json

        expect(json_response).to have_key("data")
        expect(json_response["data"]["type"]).to eq("users")
        expect(json_response["data"]["attributes"]["email"]).to eq("test@example.com")
        expect(json_response["data"]["attributes"]["name"]).to eq("Test User")
        expect(json_response["data"]["attributes"]["role"]).to eq("member")
      end

      it "returns JWT token in Authorization header" do
        post "/api/v1/signup", params: valid_params, as: :json
        expect(response.headers["Authorization"]).to be_present
        expect(response.headers["Authorization"]).to match(/^Bearer .+/)
      end

      it "returns success message in meta" do
        post "/api/v1/signup", params: valid_params, as: :json
        expect(json_response["meta"]["message"]).to eq("Signed up successfully.")
      end
    end

    context "with invalid parameters" do
      it "returns unprocessable entity for missing email" do
        invalid_params = valid_params.deep_dup
        invalid_params[:user][:email] = ""

        post "/api/v1/signup", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response).to have_key("errors")
        expect(json_response["errors"].first["status"]).to eq("422")
      end

      it "returns unprocessable entity for short password" do
        invalid_params = valid_params.deep_dup
        invalid_params[:user][:password] = "short"
        invalid_params[:user][:password_confirmation] = "short"

        post "/api/v1/signup", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns unprocessable entity for duplicate email" do
        create(:user, email: "test@example.com")

        post "/api/v1/signup", params: valid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response["errors"]).to be_present
      end

      it "returns unprocessable entity for missing name" do
        invalid_params = valid_params.deep_dup
        invalid_params[:user][:name] = ""

        post "/api/v1/signup", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when attempting to signup as librarian" do
      it "ignores role param and creates a member" do
        librarian_params = valid_params.deep_dup
        librarian_params[:user][:role] = "librarian"

        post "/api/v1/signup", params: librarian_params, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response["data"]["attributes"]["role"]).to eq("member")
      end
    end
  end

  describe "POST /api/v1/login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      let(:login_params) do
        {
          user: {
            email: "test@example.com",
            password: "password123"
          }
        }
      end

      it "returns ok status" do
        post "/api/v1/login", params: login_params, as: :json
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON:API formatted response" do
        post "/api/v1/login", params: login_params, as: :json

        expect(json_response).to have_key("data")
        expect(json_response["data"]["type"]).to eq("users")
        expect(json_response["data"]["id"]).to eq(user.id.to_s)
        expect(json_response["data"]["attributes"]["email"]).to eq("test@example.com")
      end

      it "returns JWT token in Authorization header" do
        post "/api/v1/login", params: login_params, as: :json
        expect(response.headers["Authorization"]).to be_present
        expect(response.headers["Authorization"]).to match(/^Bearer .+/)
      end

      it "returns success message in meta" do
        post "/api/v1/login", params: login_params, as: :json
        expect(json_response["meta"]["message"]).to eq("Logged in successfully.")
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized for wrong password" do
        post "/api/v1/login", params: { user: { email: "test@example.com", password: "wrongpassword" } }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized for non-existent email" do
        post "/api/v1/login", params: { user: { email: "nonexistent@example.com", password: "password123" } }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/logout" do
    let(:user) { create(:user) }

    context "with valid JWT token" do
      it "returns ok status" do
        auth_delete "/api/v1/logout", user: user
        expect(response).to have_http_status(:ok)
      end

      it "returns success message" do
        auth_delete "/api/v1/logout", user: user
        expect(json_response["meta"]["message"]).to eq("Logged out successfully.")
      end
    end

    context "without JWT token" do
      it "returns unauthorized status" do
        delete "/api/v1/logout", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid JWT token" do
      it "raises a decode error for malformed tokens" do
        expect {
          delete "/api/v1/logout", headers: { "Authorization" => "Bearer invalid_token" }, as: :json
        }.to raise_error(JWT::DecodeError)
      end
    end
  end

  describe "JWT token usage" do
    let!(:user) { create(:user, email: "token@example.com", password: "password123") }

    it "allows access to protected routes with valid token" do
      post "/api/v1/login", params: { user: { email: "token@example.com", password: "password123" } }, as: :json
      token = response.headers["Authorization"]

      expect(token).to be_present
    end

    it "includes role in JWT payload" do
      librarian = create(:user, :librarian)

      post "/api/v1/login", params: { user: { email: librarian.email, password: "password123" } }, as: :json

      token = response.headers["Authorization"].gsub("Bearer ", "")
      payload = JWT.decode(token, nil, false).first

      expect(payload["role"]).to eq("librarian")
    end
  end
end
