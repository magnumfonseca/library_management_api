class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Devise modules
  devise :database_authenticatable, :registerable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # Enums
  enum :role, { member: "member", librarian: "librarian" }

  # Associations
  has_many :borrowings, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :password, length: { minimum: 6 }, if: :password_required?

  # Callbacks
  before_create :assign_jti

  def jwt_payload
    { "role" => role }
  end

  def revoke_jwt
    update!(jti: SecureRandom.uuid)
  end

  # Business logic methods
  def can_borrow_book?(book)
    member? && !has_active_borrowing_for?(book)
  end

  def has_active_borrowing_for?(book)
    borrowings.active.exists?(book: book)
  end

  def overdue_borrowings
    borrowings.overdue
  end

  def active_borrowings_count
    borrowings.active.count
  end

  private

  def assign_jti
    self.jti ||= SecureRandom.uuid
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
