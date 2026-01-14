# frozen_string_literal: true

class Response
  attr_reader :status, :data, :errors, :meta, :http_status

  SUCCESS = :success
  FAILURE = :failure

  def initialize(status:, data: nil, errors: [], meta: {}, http_status: nil)
    @status = status
    @data = data
    @errors = errors
    @meta = meta
    @http_status = http_status
  end

  def self.success(data = nil, meta: {})
    new(status: SUCCESS, data: data, meta: meta, http_status: :ok)
  end

  def self.failure(errors, http_status: :unprocessable_entity, meta: {})
    errors = [ errors ] unless errors.is_a?(Array)
    new(status: FAILURE, errors: errors, meta: meta, http_status: http_status)
  end

  def success?
    status == SUCCESS
  end

  def failure?
    status == FAILURE
  end
end
