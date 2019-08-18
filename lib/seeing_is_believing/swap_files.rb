require 'seeing_is_believing/error'
require 'seeing_is_believing/hard_core_ensure'

class SeeingIsBelieving
  class SwapFiles
    # Might honeslty make more sense to break this out into 2 different classes.
    # We've got to do some confusing state accounting since there are really 2
    # algorithms here:
    #
    # if the file exists:
    #   make sure there isn't a backup (could cause the user to lose their file)
    #   back the file up
    #   write the rewritten code to the file
    #   if we are told to show the user program
    #     move the backup over the top of the rewritten file
    #     do nothing in the ensure block
    #   else
    #     in the ensure block: move the backup over the top of the rewritten file
    # if the file DNE:
    #   write the rewritten code to the file
    #   if we are told to show the user program
    #     write the user program to the file
    #   delete the file in the ensure block
    def self.call(*args, &block)
      new(*args, &block).call
    end

    def initialize(file_path, backup_path, user_program, rewritten_program, &block)
      self.file_path         = file_path
      self.block             = block
      self.backup_path       = backup_path
      self.user_program      = user_program
      self.rewritten_program = rewritten_program
    end

    def call
      HardCoreEnsure.call \
        code: -> {
          File.exist? backup_path and
            raise TempFileAlreadyExists.new(file_path, backup_path)

          @has_file = File.exist? file_path

          if @has_file
            File.rename file_path, backup_path
            @needs_restore = true
          end

          save_file rewritten_program

          block.call self
        },
        ensure: -> {
          set_back_to_initial_conditions
        }
    end

    def show_user_program
      if @needs_restore
        restore
      else
        save_file user_program
      end
    end

    private

    attr_accessor :block, :file_path, :backup_path, :rewritten_program, :user_program

    def restore
      File.rename(backup_path, file_path)
      @needs_restore = false
    end


    def save_file(program)
      File.open file_path, 'w', external_encoding: "utf-8" do |f|
        f.write program.to_s
      end
    end

    def set_back_to_initial_conditions
      if @needs_restore
        restore
      elsif !@has_file
        File.delete(file_path)
      end
    end
  end
end
