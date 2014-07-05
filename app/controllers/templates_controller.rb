class TemplatesController < ApplicationController
  def template
    render template: 'angular/' + params[:path], layout: false
  end
end