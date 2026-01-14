# frozen_string_literal: true

require "rails_helper"

RSpec.describe Response do
  describe ".success" do
    it "creates a success response with data" do
      response = described_class.success({ id: 1 })

      expect(response).to be_success
      expect(response).not_to be_failure
      expect(response.data).to eq({ id: 1 })
      expect(response.errors).to be_empty
    end

    it "creates a success response with meta" do
      response = described_class.success({ id: 1 }, meta: { message: "Done" })

      expect(response.meta).to eq({ message: "Done" })
    end

    it "creates a success response without data" do
      response = described_class.success

      expect(response).to be_success
      expect(response.data).to be_nil
    end

    it "sets http_status to :ok by default" do
      response = described_class.success

      expect(response.http_status).to eq(:ok)
    end
  end

  describe ".failure" do
    it "creates a failure response with single error" do
      response = described_class.failure("Something went wrong")

      expect(response).to be_failure
      expect(response).not_to be_success
      expect(response.errors).to eq([ "Something went wrong" ])
      expect(response.data).to be_nil
    end

    it "creates a failure response with multiple errors" do
      errors = [ "Error 1", "Error 2" ]
      response = described_class.failure(errors)

      expect(response.errors).to eq(errors)
    end

    it "creates a failure response with meta" do
      response = described_class.failure("Error", meta: { code: "E001" })

      expect(response.meta).to eq({ code: "E001" })
    end

    it "sets http_status to :unprocessable_entity by default" do
      response = described_class.failure("Error")

      expect(response.http_status).to eq(:unprocessable_entity)
    end

    it "allows custom http_status" do
      response = described_class.failure("Error", http_status: :bad_request)

      expect(response.http_status).to eq(:bad_request)
    end

    it "supports :unauthorized status" do
      response = described_class.failure("Error", http_status: :unauthorized)

      expect(response.http_status).to eq(:unauthorized)
    end

    it "supports :forbidden status" do
      response = described_class.failure("Error", http_status: :forbidden)

      expect(response.http_status).to eq(:forbidden)
    end
  end

  describe "#success?" do
    it "returns true for success response" do
      expect(described_class.success).to be_success
    end

    it "returns false for failure response" do
      expect(described_class.failure("Error")).not_to be_success
    end
  end

  describe "#failure?" do
    it "returns true for failure response" do
      expect(described_class.failure("Error")).to be_failure
    end

    it "returns false for success response" do
      expect(described_class.success).not_to be_failure
    end
  end
end
