# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authentication::SignupService do
  describe "#call" do
    let(:valid_params) do
      {
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        name: "Test User",
        role: "member"
      }
    end

    context "with valid parameters" do
      it "returns a success response" do
        response = described_class.new(params: valid_params).call

        expect(response).to be_success
      end

      it "creates a new user" do
        expect {
          described_class.new(params: valid_params).call
        }.to change(User, :count).by(1)
      end

      it "returns the created user in data" do
        response = described_class.new(params: valid_params).call

        expect(response.data).to be_a(User)
        expect(response.data.email).to eq("test@example.com")
        expect(response.data.name).to eq("Test User")
      end

      it "includes success message in meta" do
        response = described_class.new(params: valid_params).call

        expect(response.meta[:message]).to eq("Signed up successfully.")
      end
    end

    context "with invalid parameters" do
      it "returns a failure response for missing email" do
        params = valid_params.merge(email: "")
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.errors).to include("Email can't be blank")
      end

      it "returns a failure response for invalid email format" do
        params = valid_params.merge(email: "invalid-email")
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.errors).to include("Email is invalid")
      end

      it "returns a failure response for short password" do
        params = valid_params.merge(password: "short", password_confirmation: "short")
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.errors.join).to include("Password")
      end

      it "returns a failure response for password mismatch" do
        params = valid_params.merge(password_confirmation: "different")
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.errors).to include("Password confirmation doesn't match Password")
      end

      it "returns a failure response for missing name" do
        params = valid_params.merge(name: "")
        response = described_class.new(params: params).call

        expect(response).to be_failure
        expect(response.errors).to include("Name can't be blank")
      end

      it "returns a failure response for duplicate email" do
        create(:user, email: "test@example.com")
        response = described_class.new(params: valid_params).call

        expect(response).to be_failure
        expect(response.errors).to include("Email has already been taken")
      end
    end

    context "when role is passed" do
      it "ignores role param and creates a member" do
        params = valid_params.merge(role: "librarian")
        response = described_class.new(params: params).call

        expect(response).to be_success
        expect(response.data.role).to eq("member")
      end
    end
  end
end
