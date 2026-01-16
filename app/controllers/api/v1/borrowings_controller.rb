# frozen_string_literal: true

module Api
  module V1
    class BorrowingsController < ApplicationController
      include JsonapiResponse
      include Paginatable
      include Filterable

      before_action :set_borrowing, only: [ :show, :return ]

      def index
        borrowings = policy_scope(Borrowing).includes(:book, :user)
        borrowings = apply_scope_filter(borrowings, :status, %w[active returned overdue])
        render_paginated_collection(borrowings.order(:id), serializer: BorrowingSerializer)
      end

      def show
        authorize @borrowing
        render_record(@borrowing, serializer: BorrowingSerializer)
      end

      def create
        authorize Borrowing
        response = Borrowings::CreateService.new(
          book_id: borrowing_params[:book_id],
          current_user: current_user
        ).call

        if response.success?
          render_service_success(response, serializer: BorrowingSerializer, status: :created)
        else
          render_service_failure(response)
        end
      end

      def return
        authorize @borrowing, :return?
        response = Borrowings::ReturnService.new(
          borrowing: @borrowing,
          current_user: current_user
        ).call

        if response.success?
          render_service_success(response, serializer: BorrowingSerializer)
        else
          render_service_failure(response)
        end
      end

      private

      def set_borrowing
        @borrowing = Borrowing.find(params[:id])
      end

      def borrowing_params
        params.require(:borrowing).permit(:book_id)
      end
    end
  end
end
