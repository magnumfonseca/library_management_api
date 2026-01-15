# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  def show?
    user&.librarian? || user&.member?
  end
end
