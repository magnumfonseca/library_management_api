# frozen_string_literal: true

module Dashboard
  class LibrarianDashboardService
    DEFAULT_PER_PAGE = 10

    def initialize(page: 1, per_page: DEFAULT_PER_PAGE)
      @page = page
      @per_page = per_page
    end

    def call
      members_with_overdue = fetch_members_with_overdue

      data = {
        total_books: calculate_total_books,
        total_borrowed_books: calculate_total_borrowed_books,
        books_due_today: calculate_books_due_today,
        members_with_overdue: members_with_overdue[:data],
        pagination: members_with_overdue[:pagination]
      }

      Response.success(data)
    end

    private

    def calculate_total_books
      Book.count
    end

    def calculate_total_borrowed_books
      Borrowing.active.count
    end

    def calculate_books_due_today
      Borrowing.due_today.count
    end

    def fetch_members_with_overdue
      # Build the base query
      members_query = User.member
                          .joins(:borrowings)
                          .merge(Borrowing.overdue)
                          .select("users.id, users.name, users.email, COUNT(borrowings.id) as overdue_count")
                          .group("users.id, users.name, users.email")
                          .order("overdue_count DESC")

      # Apply pagination
      paginated_members = members_query.page(@page).per(@per_page)

      {
        data: paginated_members.map do |user|
          {
            id: user.id,
            name: user.name,
            email: user.email,
            overdue_count: user.overdue_count.to_i
          }
        end,
        pagination: {
          current_page: paginated_members.current_page,
          total_pages: paginated_members.total_pages,
          total_count: paginated_members.total_count,
          per_page: @per_page
        }
      }
    end
  end
end
