# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  def create?
    user&.librarian?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
