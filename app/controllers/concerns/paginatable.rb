# frozen_string_literal: true

module Paginatable
  extend ActiveSupport::Concern

  private

  def paginate(collection)
    collection.page(page_number).per(per_page_value)
  end

  def pagination_builder(paginated_collection)
    Pagination::Builder.new(collection: paginated_collection, request: request)
  end

  def pagination_meta(paginated_collection)
    pagination_builder(paginated_collection).meta
  end

  def pagination_links(paginated_collection)
    pagination_builder(paginated_collection).links
  end

  def page_number
    raw = jsonapi_style_params? ? params.dig(:page, :number) : params[:page]
    page = raw.to_i
    page.positive? ? page : 1
  end

  def per_page_value
    raw = jsonapi_style_params? ? params.dig(:page, :size) : params[:per_page]
    per_page = raw.to_i
    return Kaminari.config.default_per_page if per_page <= 0

    [ per_page, Kaminari.config.max_per_page ].min
  end

  def jsonapi_style_params?
    params[:page].is_a?(ActionController::Parameters) || params[:page].is_a?(Hash)
  end
end
