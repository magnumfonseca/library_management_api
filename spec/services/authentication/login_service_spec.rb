# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authentication::LoginService do
  describe "#call" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      let(:params) { { email: "test@example.com", password: "password123" } }

      it "returns a success response" do
        response = described_class.new(params: params).call

        expect(response).to be_success
        expect(response.http_status).to eq(:ok)
      end

      it "returns the user in data" do
        response = described_class.new(params: params).call

        expect(response.data).to eq(user)
      end

      it "includes success message in meta" do
        response = described_class.new(params: params).call

        expect(response.meta[:message]).to eq("Logged in successfully.")
      end
    end

    context "with invalid password (401 Unauthorized)" do
      let(:params) { { email: "test@example.com", password: "wrongpassword" } }

      it "returns a failure response" do
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unauthorized)
      end

      it "returns error message" do
        response = described_class.new(params: params).call

        expect(response.errors).to include("Invalid email or password.")
      end
    end

    context "with non-existent email (401 Unauthorized)" do
      let(:params) { { email: "nonexistent@example.com", password: "password123" } }

      it "returns a failure response with unauthorized status" do
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unauthorized)
      end

      it "returns generic error message" do
        response = described_class.new(params: params).call

        expect(response.errors).to include("Invalid email or password.")
      end
    end

    context "with missing credentials (400 Bad Request)" do
      it "returns bad request for missing email" do
        response = described_class.new(params: { email: "", password: "password123" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
        expect(response.errors).to include("Email and password are required.")
      end

      it "returns bad request for nil email" do
        response = described_class.new(params: { email: nil, password: "password123" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
      end

      it "returns bad request for missing password" do
        response = described_class.new(params: { email: "test@example.com", password: "" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
        expect(response.errors).to include("Email and password are required.")
      end

      it "returns bad request for nil password" do
        response = described_class.new(params: { email: "test@example.com", password: nil }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
      end

      it "returns bad request when both are missing" do
        response = described_class.new(params: { email: "", password: "" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
      end
    end

    context "with inactive account (403 Forbidden)" do
      it "returns forbidden when user is not active for authentication" do
        allow(user).to receive(:active_for_authentication?).and_return(false)
        allow(user).to receive(:inactive_message).and_return(:inactive)
        allow(User).to receive(:find_by).with(email: "test@example.com").and_return(user)

        response = described_class.new(params: { email: "test@example.com", password: "password123" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:forbidden)
        expect(response.errors).to include("Your account is not active.")
      end

      it "returns specific message for unconfirmed account" do
        allow(user).to receive(:active_for_authentication?).and_return(false)
        allow(user).to receive(:inactive_message).and_return(:unconfirmed)
        allow(User).to receive(:find_by).with(email: "test@example.com").and_return(user)

        response = described_class.new(params: { email: "test@example.com", password: "password123" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:forbidden)
        expect(response.errors).to include("Please confirm your email address before signing in.")
      end

      it "returns specific message for locked account" do
        allow(user).to receive(:active_for_authentication?).and_return(false)
        allow(user).to receive(:inactive_message).and_return(:locked)
        allow(User).to receive(:find_by).with(email: "test@example.com").and_return(user)

        response = described_class.new(params: { email: "test@example.com", password: "password123" }).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:forbidden)
        expect(response.errors).to include("Your account has been locked. Please contact support.")
      end
    end
  end
end
