# frozen_string_literal: true

module Api
  module V1
    class BooksController < ApplicationController
      include JsonapiResponse
      include Paginatable

      before_action :set_book, only: [ :show, :update, :destroy ]

      def index
        books = policy_scope(Book)
        books = books.by_title(params[:title]) if params[:title].present?
        books = books.by_author(params[:author]) if params[:author].present?
        books = books.by_genre(params[:genre]) if params[:genre].present?

        # Preload borrowings for members to avoid N+1 queries
        books = books.includes(:borrowings) if current_user&.member?

        render_paginated_collection(books.order(:id), serializer: BookSerializer, params: { current_user: current_user })
      end

      def show
        authorize @book

        # Preload borrowings for members to avoid N+1 queries
        @book = Book.includes(:borrowings).find(@book.id) if current_user&.member?

        render_record(@book, serializer: BookSerializer, params: { current_user: current_user })
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
    end
  end
end
