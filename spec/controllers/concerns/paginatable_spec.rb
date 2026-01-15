# frozen_string_literal: true

require "rails_helper"

RSpec.describe Paginatable, type: :controller do
  # Create a test controller that includes the concern
  controller(ActionController::API) do
    include Paginatable

    def index
      render json: { page: page_number, per_page: per_page_value }
    end
  end

  describe "#page_number" do
    context "with standard params" do
      it "returns page number from params" do
        get :index, params: { page: 2 }
        expect(JSON.parse(response.body)["page"]).to eq(2)
      end

      it "defaults to page 1 when not provided" do
        get :index, params: {}
        expect(JSON.parse(response.body)["page"]).to eq(1)
      end

      it "handles invalid page number by defaulting to 1" do
        get :index, params: { page: "invalid" }
        expect(JSON.parse(response.body)["page"]).to eq(1)
      end

      it "handles negative page number by defaulting to 1" do
        get :index, params: { page: -5 }
        expect(JSON.parse(response.body)["page"]).to eq(1)
      end

      it "handles zero page number by defaulting to 1" do
        get :index, params: { page: 0 }
        expect(JSON.parse(response.body)["page"]).to eq(1)
      end
    end

    context "with JSON:API style params (page[number])" do
      it "returns page number from page[number]" do
        get :index, params: { page: { number: 3 } }
        expect(JSON.parse(response.body)["page"]).to eq(3)
      end

      it "defaults to 1 when page[number] is not provided" do
        get :index, params: { page: { size: 10 } }
        expect(JSON.parse(response.body)["page"]).to eq(1)
      end
    end
  end

  describe "#per_page_value" do
    context "with standard params" do
      it "returns per_page from params" do
        get :index, params: { per_page: 15 }
        expect(JSON.parse(response.body)["per_page"]).to eq(15)
      end

      it "defaults to configured default when not provided" do
        get :index, params: {}
        expect(JSON.parse(response.body)["per_page"]).to eq(Kaminari.config.default_per_page)
      end

      it "caps per_page at max_per_page configuration" do
        get :index, params: { per_page: 500 }
        expect(JSON.parse(response.body)["per_page"]).to eq(Kaminari.config.max_per_page)
      end

      it "handles invalid per_page by using default" do
        get :index, params: { per_page: "invalid" }
        expect(JSON.parse(response.body)["per_page"]).to eq(Kaminari.config.default_per_page)
      end

      it "handles zero per_page by using default" do
        get :index, params: { per_page: 0 }
        expect(JSON.parse(response.body)["per_page"]).to eq(Kaminari.config.default_per_page)
      end

      it "handles negative per_page by using default" do
        get :index, params: { per_page: -10 }
        expect(JSON.parse(response.body)["per_page"]).to eq(Kaminari.config.default_per_page)
      end
    end

    context "with JSON:API style params (page[size])" do
      it "returns per_page from page[size]" do
        get :index, params: { page: { size: 50 } }
        expect(JSON.parse(response.body)["per_page"]).to eq(50)
      end

      it "caps page[size] at max_per_page" do
        get :index, params: { page: { size: 200 } }
        expect(JSON.parse(response.body)["per_page"]).to eq(Kaminari.config.max_per_page)
      end
    end
  end

  describe "#paginate" do
    controller(ActionController::API) do
      include Paginatable

      def index
        books = Book.all
        paginated = paginate(books)
        render json: { ids: paginated.pluck(:id), count: paginated.size }
      end
    end

    let!(:books) { create_list(:book, 30) }

    it "paginates the collection with default values" do
      get :index, params: {}
      result = JSON.parse(response.body)
      expect(result["count"]).to eq(25) # Default per_page
    end

    it "paginates the collection with custom per_page" do
      get :index, params: { per_page: 10 }
      result = JSON.parse(response.body)
      expect(result["count"]).to eq(10)
    end

    it "returns correct page" do
      get :index, params: { page: 2, per_page: 10 }
      result = JSON.parse(response.body)
      expect(result["count"]).to eq(10)
      expect(result["ids"]).not_to include(books.first.id)
    end

    it "returns empty for page beyond range" do
      get :index, params: { page: 100, per_page: 10 }
      result = JSON.parse(response.body)
      expect(result["count"]).to eq(0)
      expect(result["ids"]).to eq([])
    end
  end

  describe "#pagination_meta" do
    controller(ActionController::API) do
      include Paginatable

      def index
        books = Book.all
        paginated = paginate(books)
        render json: pagination_meta(paginated)
      end
    end

    let!(:books) { create_list(:book, 55) }

    it "returns nested structure under page key" do
      get :index, params: { per_page: 10 }
      result = JSON.parse(response.body)
      expect(result).to have_key("page")
    end

    it "returns correct total" do
      get :index, params: { per_page: 10 }
      result = JSON.parse(response.body)
      expect(result["page"]["total"]).to eq(55)
    end

    it "returns correct totalPages" do
      get :index, params: { per_page: 10 }
      result = JSON.parse(response.body)
      expect(result["page"]["totalPages"]).to eq(6)
    end

    it "returns correct number (current page)" do
      get :index, params: { page: 3, per_page: 10 }
      result = JSON.parse(response.body)
      expect(result["page"]["number"]).to eq(3)
    end

    it "returns correct size (per_page)" do
      get :index, params: { per_page: 15 }
      result = JSON.parse(response.body)
      expect(result["page"]["size"]).to eq(15)
    end

    context "with empty collection" do
      before { Book.destroy_all }

      it "returns zero counts" do
        get :index, params: {}
        result = JSON.parse(response.body)
        expect(result["page"]["total"]).to eq(0)
        expect(result["page"]["totalPages"]).to eq(0)
      end
    end
  end

  describe "#pagination_links" do
    controller(ActionController::API) do
      include Paginatable

      def index
        books = Book.all
        paginated = paginate(books)
        render json: pagination_links(paginated)
      end
    end

    let!(:books) { create_list(:book, 55) }

    def decoded(url)
      CGI.unescape(url)
    end

    it "returns self link with current page params" do
      get :index, params: { page: 2, per_page: 10 }
      result = JSON.parse(response.body)
      expect(decoded(result["self"])).to include("page[number]=2")
      expect(decoded(result["self"])).to include("page[size]=10")
    end

    it "returns first link pointing to page 1" do
      get :index, params: { page: 3, per_page: 10 }
      result = JSON.parse(response.body)
      expect(decoded(result["first"])).to include("page[number]=1")
    end

    it "returns last link pointing to last page" do
      get :index, params: { per_page: 10 }
      result = JSON.parse(response.body)
      expect(decoded(result["last"])).to include("page[number]=6") # 55 items / 10 per page = 6 pages
    end

    context "on first page" do
      it "returns prev as null" do
        get :index, params: { page: 1, per_page: 10 }
        result = JSON.parse(response.body)
        expect(result["prev"]).to be_nil
      end

      it "returns next link to page 2" do
        get :index, params: { page: 1, per_page: 10 }
        result = JSON.parse(response.body)
        expect(decoded(result["next"])).to include("page[number]=2")
      end
    end

    context "on middle page" do
      it "returns prev link to previous page" do
        get :index, params: { page: 3, per_page: 10 }
        result = JSON.parse(response.body)
        expect(decoded(result["prev"])).to include("page[number]=2")
      end

      it "returns next link to next page" do
        get :index, params: { page: 3, per_page: 10 }
        result = JSON.parse(response.body)
        expect(decoded(result["next"])).to include("page[number]=4")
      end
    end

    context "on last page" do
      it "returns prev link to previous page" do
        get :index, params: { page: 6, per_page: 10 }
        result = JSON.parse(response.body)
        expect(decoded(result["prev"])).to include("page[number]=5")
      end

      it "returns next as null" do
        get :index, params: { page: 6, per_page: 10 }
        result = JSON.parse(response.body)
        expect(result["next"]).to be_nil
      end
    end

    context "with empty collection" do
      before { Book.destroy_all }

      it "returns last link to page 1" do
        get :index, params: {}
        result = JSON.parse(response.body)
        expect(decoded(result["last"])).to include("page[number]=1")
      end

      it "returns next as null" do
        get :index, params: {}
        result = JSON.parse(response.body)
        expect(result["next"]).to be_nil
      end
    end
  end
end
