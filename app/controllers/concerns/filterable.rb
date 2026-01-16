# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  private

  def apply_filters(scope, allowed_filters)
    allowed_filters.each do |filter|
      next unless params[filter].present?
      next unless scope.respond_to?("by_#{filter}")

      scope = scope.public_send("by_#{filter}", params[filter])
    end
    scope
  end

  def apply_scope_filter(scope, param_key, valid_scopes)
    return scope unless params[param_key].present?
    return scope unless valid_scopes.include?(params[param_key])

    scope.public_send(params[param_key])
  end
end
