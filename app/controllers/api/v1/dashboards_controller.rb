# frozen_string_literal: true

module Api
  module V1
    class DashboardsController < ApplicationController
      include JsonapiResponse

      skip_after_action :verify_authorized

      def show
        authorize :dashboard

        response = dashboard_service.call

        if response.success?
          render json: { data: response.data }, status: :ok
        else
          render_service_failure(response)
        end
      end

      private

      def dashboard_service
        service_class.new(
          current_user: current_user,
          page: pagination_params[:page],
          per_page: pagination_params[:per_page]
        )
      end

      def service_class
        current_user.librarian? ? Dashboard::LibrarianDashboardService : Dashboard::MemberDashboardService
      end

      def pagination_params
        {
          page: params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || service_class::DEFAULT_PER_PAGE
        }
      end

      def default_per_page
        service_class::DEFAULT_PER_PAGE
      end
    end
  end
end
