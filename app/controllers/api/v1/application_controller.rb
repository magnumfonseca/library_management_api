module Api
  module V1
    class ApplicationController < ActionController::API
      include Pundit::Authorization

      before_action :authenticate_user!
      after_action :verify_authorized, except: [ :index, :show ]

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
    end
  end
end
