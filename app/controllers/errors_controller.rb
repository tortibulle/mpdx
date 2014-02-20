class ErrorsController < ApplicationController
  def error_404
    @status = 404
    respond
  end

  def error_500
    @status = 500
    respond
  end

  def respond
    respond_to do |format|
      format.html { render 'application/error', layout: false, status: @status }
      format.all { render nothing: true, status: @status }
    end
  end
end
