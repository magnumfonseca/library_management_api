# frozen_string_literal: true

module Pagination
  class Builder
    attr_reader :collection, :request

    def initialize(collection:, request:)
      @collection = collection
      @request = request
    end

    def meta
      {
        page: {
          total: collection.total_count,
          totalPages: collection.total_pages,
          number: collection.current_page,
          size: collection.limit_value
        }
      }
    end

    def links
      {
        self: build_url(current_page),
        first: build_url(1),
        last: build_url(last_page),
        prev: current_page > 1 ? build_url(current_page - 1) : nil,
        next: current_page < total_pages ? build_url(current_page + 1) : nil
      }
    end

    def result
      {
        collection: collection,
        meta: meta,
        links: links
      }
    end

    private

    def current_page
      collection.current_page
    end

    def total_pages
      collection.total_pages
    end

    def last_page
      total_pages > 0 ? total_pages : 1
    end

    def page_size
      collection.limit_value
    end

    def build_url(page)
      base = "#{request.base_url}#{request.path}"
      query_params = preserved_params.merge(pagination_params(page))
      "#{base}?#{query_params.to_query}"
    end

    def preserved_params
      request.query_parameters.except("page", "per_page", "page[number]", "page[size]")
    end

    def pagination_params(page)
      { "page[number]" => page, "page[size]" => page_size }
    end
  end
end
