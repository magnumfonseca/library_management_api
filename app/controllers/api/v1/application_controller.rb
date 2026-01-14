module Api
  module V1
    class ApplicationController < ActionController::API
      include Pundit::Authorization

      before_action :authenticate_user!

      rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

      private

      def user_not_authorized
        render json: {
          errors: [
            {
              status: "403",
              title: "Forbidden",
              detail: "You are not authorized to perform this action"
            }
          ]
        }, status: :forbidden
      end

      def record_not_found
        render json: {
          errors: [
            {
              status: "404",
              title: "Not Found",
              detail: "Record not found"
            }
          ]
        }, status: :not_found
      end

      def render_jsonapi_success(data, status: :ok, meta: nil)
        response = data
        response[:meta] = meta if meta.present?
        render json: response, status: status
      end

      def render_jsonapi_error(title:, detail:, status: :unprocessable_entity, errors: [])
        error_response = {
          errors: [
            {
              status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status].to_s,
              title: title,
              detail: detail
            }
          ]
        }

        if errors.present?
          error_response[:errors] += errors.map do |error|
            {
              status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status].to_s,
              title: "Validation Error",
              detail: error
            }
          end
        end

        render json: error_response, status: status
      end
    end
  end
end
