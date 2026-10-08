require "fileutils"
require "securerandom"

module MemoryServices
  class PhotoStorage
    def store(photos)
      Array(photos).compact.map do |photo|
        next unless photo.respond_to?(:original_filename)

        filename = "#{SecureRandom.uuid}-#{sanitize(photo.original_filename)}"
        path = Rails.root.join("storage", "uploads", filename)

        FileUtils.mkdir_p(path.dirname)
        File.binwrite(path, photo.read)

        "/uploads/#{filename}"
      end.compact
    end

    private

    def sanitize(filename)
      File.basename(filename).gsub(/[^A-Za-z0-9.\-_]/, "-")
    end
  end
end
