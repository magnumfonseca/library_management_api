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
    param_value = params[param_key]
    return scope unless param_value.present?

    # Only use whitelisted scope names - prevents arbitrary method execution
    validated_scope = valid_scopes.find { |s| s == param_value.to_s }
    return scope unless validated_scope

    scope.public_send(validated_scope)
  end
end
