# frozen_string_literal: true

module Api
  module V1
    class BooksController < ApplicationController
      include JsonapiResponse

      before_action :set_book, only: [ :show, :update, :destroy ]

      def index
        books = policy_scope(Book)
        render_collection(books, serializer: BookSerializer)
      end

      def show
        authorize @book
        render_record(@book, serializer: BookSerializer)
      end

      def create
        authorize Book
        response = Books::CreateService.new(
          params: book_params,
          current_user: current_user
        ).call

        if response.success?
          render_service_success(response, serializer: BookSerializer, status: :created)
        else
          render_service_failure(response)
        end
      end

      def update
        authorize @book
        response = Books::UpdateService.new(
          book: @book,
          params: book_params,
          current_user: current_user
        ).call

        if response.success?
          render_service_success(response, serializer: BookSerializer)
        else
          render_service_failure(response)
        end
      end

      def destroy
        authorize @book
        response = Books::DeleteService.new(
          book: @book,
          current_user: current_user
        ).call

        if response.success?
          head :no_content
        else
          render_service_failure(response)
        end
      end

      private

      def set_book
        @book = Book.find(params[:id])
      end

      def book_params
        params.require(:book).permit(:title, :author, :genre, :isbn, :total_copies)
      end
    end
  end
end
