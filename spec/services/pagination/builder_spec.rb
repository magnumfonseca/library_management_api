# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pagination::Builder do
  let(:request) do
    instance_double(
      ActionDispatch::Request,
      base_url: "http://localhost:3000",
      path: "/api/v1/books",
      query_parameters: {}
    )
  end

  let!(:books) { create_list(:book, 55) }
  let(:collection) { Book.all.page(1).per(10) }

  subject { described_class.new(collection: collection, request: request) }

  describe "#meta" do
    it "returns nested structure under page key" do
      expect(subject.meta).to have_key(:page)
    end

    it "returns correct total" do
      expect(subject.meta[:page][:total]).to eq(55)
    end

    it "returns correct totalPages" do
      expect(subject.meta[:page][:totalPages]).to eq(6)
    end

    it "returns correct number (current page)" do
      collection = Book.all.page(3).per(10)
      builder = described_class.new(collection: collection, request: request)
      expect(builder.meta[:page][:number]).to eq(3)
    end

    it "returns correct size" do
      expect(subject.meta[:page][:size]).to eq(10)
    end
  end

  describe "#links" do
    def decoded(url)
      CGI.unescape(url)
    end

    it "returns self link with full URL" do
      expect(subject.links[:self]).to start_with("http://localhost:3000")
      expect(subject.links[:self]).to include("/api/v1/books")
      expect(decoded(subject.links[:self])).to include("page[number]=1")
    end

    it "returns first link pointing to page 1" do
      collection = Book.all.page(3).per(10)
      builder = described_class.new(collection: collection, request: request)
      expect(decoded(builder.links[:first])).to include("page[number]=1")
    end

    it "returns last link pointing to last page" do
      expect(decoded(subject.links[:last])).to include("page[number]=6")
    end

    context "on first page" do
      it "returns prev as nil" do
        expect(subject.links[:prev]).to be_nil
      end

      it "returns next link to page 2" do
        expect(decoded(subject.links[:next])).to include("page[number]=2")
      end
    end

    context "on middle page" do
      let(:collection) { Book.all.page(3).per(10) }

      it "returns prev link to previous page" do
        expect(decoded(subject.links[:prev])).to include("page[number]=2")
      end

      it "returns next link to next page" do
        expect(decoded(subject.links[:next])).to include("page[number]=4")
      end
    end

    context "on last page" do
      let(:collection) { Book.all.page(6).per(10) }

      it "returns prev link to previous page" do
        expect(decoded(subject.links[:prev])).to include("page[number]=5")
      end

      it "returns next as nil" do
        expect(subject.links[:next]).to be_nil
      end
    end

    context "with empty collection" do
      before { Book.destroy_all }
      let(:collection) { Book.all.page(1).per(10) }

      it "returns last link to page 1" do
        expect(decoded(subject.links[:last])).to include("page[number]=1")
      end
    end
  end

  describe "#links preserves existing query params" do
    let(:request) do
      instance_double(
        ActionDispatch::Request,
        base_url: "http://localhost:3000",
        path: "/api/v1/books",
        query_parameters: { "genre" => "fiction", "author" => "Tolkien" }
      )
    end

    def decoded(url)
      CGI.unescape(url)
    end

    it "includes existing params in self link" do
      expect(decoded(subject.links[:self])).to include("genre=fiction")
      expect(decoded(subject.links[:self])).to include("author=Tolkien")
    end

    it "includes existing params in next link" do
      expect(decoded(subject.links[:next])).to include("genre=fiction")
      expect(decoded(subject.links[:next])).to include("author=Tolkien")
    end

    it "includes pagination params alongside existing params" do
      expect(decoded(subject.links[:self])).to include("page[number]=1")
      expect(decoded(subject.links[:next])).to include("page[number]=2")
    end
  end

  describe "#result" do
    it "returns hash with both meta and links" do
      result = subject.result
      expect(result).to have_key(:meta)
      expect(result).to have_key(:links)
    end

    it "returns the collection" do
      expect(subject.result[:collection]).to eq(collection)
    end
  end
end
