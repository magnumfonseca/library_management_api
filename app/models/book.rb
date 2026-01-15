class Book < ApplicationRecord
  # Associations
  has_many :borrowings, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :author, presence: true
  validates :genre, presence: true
  validates :isbn, presence: true, uniqueness: true
  validates :total_copies, numericality: { greater_than: 0 }

  # Scopes
  scope :by_title, ->(title) { where("title ILIKE ?", "%#{title}%") }
  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_author, ->(author) { where("author ILIKE ?", "%#{author}%") }
  scope :available, -> {
    where("total_copies > ?", 0)
      .joins("LEFT JOIN borrowings ON books.id = borrowings.book_id AND borrowings.returned_at IS NULL")
      .select("books.*, COUNT(borrowings.id) as active_count")
      .group("books.id")
      .having("books.total_copies > COUNT(borrowings.id)")
    }

  # Business logic
  def active_borrowings_count
    borrowings.active.count
  end

  def available_copies
    total_copies - active_borrowings_count
  end

  def available?
    available_copies > 0
  end

  def borrowed_by?(user)
    borrowings.active.exists?(user: user)
  end
end
