class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found(exception)
    render json: {
      errors: [ {
        status: "404",
        title: "Not Found",
        detail: exception.message
      } ]
    }, status: :not_found
  end
end
