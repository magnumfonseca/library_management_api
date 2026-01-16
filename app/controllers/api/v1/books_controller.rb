# frozen_string_literal: true

module Api
  module V1
    class BooksController < ApplicationController
      include JsonapiResponse
      include Paginatable
      include Filterable

      before_action :set_book, only: [ :show, :update, :destroy ]

      def index
        books = policy_scope(Book)
        books = apply_filters(books, %i[title author genre])
        books = preload_for_serialization(books)
        render_paginated_collection(books.order(:id), serializer: BookSerializer, params: serializer_params)
      end

      def show
        authorize @book
        @book = preload_for_serialization(Book.where(id: @book.id)).first
        render_record(@book, serializer: BookSerializer, params: serializer_params)
      end

      def create
        authorize Book
        response = Books::CreateService.new(
          params: book_params,
          current_user: current_user
        ).call

        if response.success?
          render_service_success(response, serializer: BookSerializer, params: { current_user: current_user }, status: :created)
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
          render_service_success(response, serializer: BookSerializer, params: { current_user: current_user })
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

      def serializer_params
        { current_user: current_user }
      end

      def preload_for_serialization(scope)
        # Only preload borrowings for members who need to see borrowed_by_current_user
        current_user&.member? ? scope.includes(:borrowings) : scope
      end
    end
  end
end
