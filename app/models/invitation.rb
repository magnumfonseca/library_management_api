# frozen_string_literal: true

class Invitation < ApplicationRecord
  EXPIRATION_PERIOD = 7.days

  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[librarian] }
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where(accepted_at: nil).where("expires_at <= ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  def pending?
    accepted_at.nil? && !expired?
  end

  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def accept!
    raise "Invitation already accepted" if accepted?
    raise "Invitation has expired" if expired?

    update!(accepted_at: Time.current)
  end

  def build_user(params)
    User.new(
      email: email,
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      name: params[:name],
      role: role
    )
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_PERIOD.from_now
  end
end
