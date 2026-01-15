# frozen_string_literal: true

class BookPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user&.librarian?
  end

  def update?
    user&.librarian?
  end

  def destroy?
    user&.librarian?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
