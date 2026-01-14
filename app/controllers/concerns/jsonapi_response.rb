# frozen_string_literal: true

module JsonapiResponse
  extend ActiveSupport::Concern

  private

  def render_service_success(response, serializer:, status: :ok)
    render json: {
      data: serializer.new(response.data).as_jsonapi[:data],
      meta: response.meta
    }, status: status
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
end
