require 'seeing_is_believing/error'
require 'seeing_is_believing/hard_core_ensure'

class SeeingIsBelieving
  class BackupFile
    def self.call(*args, &block)
      new(*args, &block).call
    end

    def initialize(file_path, backup_filename, &block)
      self.file_path       = file_path
      self.block           = block
      self.backup_filename = backup_filename
    end

    def call
      HardCoreEnsure.call \
        code: -> {
          we_will_not_overwrite_existing_backup_file!
          backup_existing_file
          block.call
        },
        ensure: -> {
          set_back_to_initial_conditions
        }
    end

    private

    attr_accessor :block, :file_path, :backup_filename

    def we_will_not_overwrite_existing_backup_file!
      raise TempFileAlreadyExists.new(file_path, backup_filename) if File.exist? backup_filename
    end

    def backup_existing_file
      return unless File.exist? file_path
      File.rename file_path, backup_filename
      @was_backed_up = true
    end

    def set_back_to_initial_conditions
      if @was_backed_up
        File.rename(backup_filename, file_path)
      else
        File.delete(file_path)
      end
    end
  end
end
