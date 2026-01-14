class Borrowing < ApplicationRecord
  BORROWING_PERIOD_DAYS = 14
  CLOSE_DATE_THRESHOLD_DAYS = 3

  # Associations
  belongs_to :user
  belongs_to :book

  # Validations
  validates :borrowed_at, presence: true
  validates :due_date, presence: true
  validate :book_must_be_available, on: :create
  # Model-level guard for nicer error messages
  validates :book_id,
            uniqueness: {
              scope: :user_id,
              conditions: -> { where(returned_at: nil) },
              message: "You already have an active borrowing for this book"
            }

  # Callbacks
  before_validation :set_dates, on: :create

  # Scopes
  scope :active, -> { where(returned_at: nil) }
  scope :returned, -> { where.not(returned_at: nil) }
  scope :overdue, -> { active.where("due_date < ?", Time.current) }
  scope :due_today, -> { active.where(due_date: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :due_soon, -> { active.where(due_date: Time.current..CLOSE_DATE_THRESHOLD_DAYS.days.from_now) }

  # Business logic
  def active?
    returned_at.nil?
  end

  def returned?
    returned_at.present?
  end

  def overdue?
    active? && due_date < Time.current
  end

  def days_overdue
    return 0 unless overdue?

    ((Time.current - due_date) / 1.day).ceil
  end

  def mark_as_returned!(return_time = Time.current)
    raise StandardError, "Already returned" if returned?

    update!(returned_at: return_time)
  end

  private

  def set_dates
    self.borrowed_at ||= Time.current
    self.due_date ||= borrowed_at + BORROWING_PERIOD_DAYS.days
  end

  def book_must_be_available
    if book && !book.available?
      errors.add(:book, "is not available for borrowing")
    end
  end
end
