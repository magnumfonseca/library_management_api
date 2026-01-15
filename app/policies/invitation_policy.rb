# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  def index?
    user&.librarian?
  end

  def show?
    user&.librarian?
  end

  def create?
    user&.librarian?
  end

  def destroy?
    user&.librarian? && record.pending?
  end

  class Scope < Scope
    def resolve
      if user&.librarian?
        scope.all
      else
        scope.none
      end
    end
  end
end
