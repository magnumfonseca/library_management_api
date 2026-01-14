class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Devise modules
  devise :database_authenticatable, :registerable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # Enums
  enum role: { member: 'member', librarian: 'librarian' }

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :password, length: { minimum: 6 }, if: :password_required?

  # Callbacks
  before_create :assign_jti

  # Scopes
  scope :members, -> { where(role: 'member') }
  scope :librarians, -> { where(role: 'librarian') }

  def jwt_payload
    { 'role' => role }
  end

  def revoke_jwt
    update!(jti: SecureRandom.uuid)
  end

  def as_json(options = {})
    super(options.merge(only: %i[id email name role]))
  end

  private

  def assign_jti
    self.jti ||= SecureRandom.uuid
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
