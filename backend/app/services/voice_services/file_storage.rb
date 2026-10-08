require "fileutils"
require "securerandom"

module VoiceServices
  class FileStorage
    def store(upload, prefix: "voice-sample")
      filename = "#{prefix}-#{SecureRandom.uuid}-#{sanitize(upload.original_filename)}"
      path = Rails.root.join("storage", "uploads", filename)

      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, upload.read)

      "/uploads/#{filename}"
    end

    def store_audio(bytes, extension: "wav")
      filename = "speech-#{SecureRandom.uuid}.#{extension}"
      path = Rails.root.join("storage", "uploads", filename)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, bytes)
      "/uploads/#{filename}"
    end

    private

    def sanitize(filename)
      File.basename(filename).gsub(/[^A-Za-z0-9.\-_]/, "-")
    end
  end
end
