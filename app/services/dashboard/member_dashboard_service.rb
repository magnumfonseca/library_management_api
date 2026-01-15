# frozen_string_literal: true

module Dashboard
  class MemberDashboardService
    DEFAULT_PER_PAGE = 20

    def initialize(current_user:, page: 1, per_page: DEFAULT_PER_PAGE)
      @current_user = current_user
      @page = page
      @per_page = per_page
    end

    def call
      borrowed_books = fetch_borrowed_books
      overdue_books = fetch_overdue_books

      data = {
        borrowed_books: borrowed_books[:data],
        overdue_books: overdue_books[:data],
        summary: {
          total_borrowed: borrowed_books[:total_count],
          total_overdue: overdue_books[:total_count]
        },
        pagination: borrowed_books[:pagination]
      }

      Response.success(data)
    end

    private

    def fetch_borrowed_books
      # Paginate all borrowed books
      borrowings = @current_user.borrowings
                                .active
                                .includes(:book)
                                .order(due_date: :asc)
                                .page(@page)
                                .per(@per_page)

      {
        data: borrowings.map { |borrowing| format_borrowing(borrowing) },
        total_count: borrowings.total_count,
        pagination: {
          current_page: borrowings.current_page,
          total_pages: borrowings.total_pages,
          total_count: borrowings.total_count,
          per_page: @per_page
        }
      }
    end

    def fetch_overdue_books
      # Get total count of overdue (not paginated separately)
      overdue_borrowings = @current_user.borrowings
                                        .overdue
                                        .includes(:book)
                                        .order(due_date: :asc)

      {
        data: overdue_borrowings.map { |borrowing| format_borrowing(borrowing) },
        total_count: overdue_borrowings.count
      }
    end

    def format_borrowing(borrowing)
      {
        id: borrowing.id,
        book: {
          id: borrowing.book.id,
          title: borrowing.book.title,
          author: borrowing.book.author
        },
        borrowed_at: borrowing.borrowed_at,
        due_date: borrowing.due_date,
        days_until_due: calculate_days_until_due(borrowing),
        is_overdue: borrowing.overdue?,
        days_overdue: borrowing.days_overdue
      }
    end

    def calculate_days_until_due(borrowing)
      return 0 if borrowing.overdue?
      ((borrowing.due_date - Time.current) / 1.day).ceil
    end
  end
end
