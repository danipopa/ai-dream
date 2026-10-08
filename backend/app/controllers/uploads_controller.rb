class UploadsController < ApplicationController
  def show
    path = Rails.root.join("storage", "uploads", params[:filename])
    return head :not_found unless path.file?

    send_file path, disposition: "inline"
  end
end
