# frozen_string_literal: true

class DashboardPolicy < ApplicationPolicy
  def show?
    user&.librarian? || user&.member?
  end

  def librarian?
    user&.librarian?
  end

  def member?
    user&.member?
  end
end
