# frozen_string_literal: true

module JsonapiResponse
  extend ActiveSupport::Concern

  private

  def render_jsonapi(data, serializer:, meta: {}, links: {}, params: {}, status: :ok)
    serialized = serializer.new(data, params: params).serializable_hash
    response_body = serialized.merge(meta: meta)
    response_body[:links] = links if links.present?
    render json: response_body, status: status
  end

  def render_service_success(response, serializer:, params: {}, status: :ok)
    meta = response.meta if response.respond_to?(:meta)
    render_jsonapi(response.data, serializer: serializer, meta: meta, params: params, status: status)
  end

  def render_service_failure(response)
    status_code = Rack::Utils.status_code(response.http_status)
    title = Rack::Utils::HTTP_STATUS_CODES[status_code]

    render json: {
      errors: response.errors.map do |message|
        {
          status: status_code.to_s,
          title: title,
          detail: message
        }
      end
    }, status: response.http_status
  end

  def render_collection(collection, serializer:, meta: {}, links: {}, params: {})
    render_jsonapi(collection, serializer: serializer, meta: meta, links: links, params: params, status: :ok)
  end

  def render_paginated_collection(collection, serializer:, params: {})
    paginated = paginate(collection)
    builder = pagination_builder(paginated)
    render_jsonapi(
      paginated,
      serializer: serializer,
      meta: builder.meta,
      links: builder.links,
      params: params,
      status: :ok
    )
  end

  def render_record(record, serializer:, meta: {}, params: {}, status: :ok)
    render_jsonapi(record, serializer: serializer, meta: meta, params: params, status: status)
  end
end
