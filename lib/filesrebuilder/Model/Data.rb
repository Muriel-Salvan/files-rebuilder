require 'filesrebuilder/Model/DirInfo'

module FilesRebuilder

  module Model

    # Complete data model.
    # this data model is thread safe.
    class Data

      dont_rubyserial :global_mutex

      # Constructor
      def initialize
        @dirs_info = DirInfo.new
        # Mutex protecting any access to the data
        @global_mutex = Mutex.new
      end

      # Callback called when RubySerial loads this object.
      # Called after instance variables have been replaced.
      def rubyserial_onload
        @global_mutex = Mutex.new
      end

      # Get the directory info of a given directory
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The corresponding directory info, or nil if none
      def dir_info(dir_name)
        dir_info = nil

        @global_mutex.synchronize do
          dir_info = dir_info_unprotected(dir_name)
        end

        return dir_info
      end

      # Get or create a dir info of a given directory
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The resulting DirInfo
      def get_or_create_dir_info(dir_name)
        dir_info = nil

        @global_mutex.synchronize do
          dir_info = get_or_create_dir_info_unprotected(dir_name)
        end

        return dir_info
      end

      # Store a subdir info when we already have access to the DirInfo
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The directory info to complete
      # * *dir_base_name* (_String_): The directory base name to add
      # Result::
      # * _DirInfo_: The resulting DirInfo
      def get_or_create_subdir_info(dir_info, dir_base_name)
        subdir_info = nil

        @global_mutex.synchronize do
          subdir_info = dir_info.sub_dirs[dir_base_name]
          if (subdir_info == nil)
            subdir_info = DirInfo.new
            dir_info.sub_dirs[dir_base_name] = subdir_info
          end
        end

        return subdir_info
      end

      # Store a file info when we already have access to the DirInfo
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The directory info to complete
      # * *file_base_name* (_String_): The file base name to add
      # Result::
      # * _FileInfo_: The resulting FileInfo
      def get_or_create_file_info(dir_info, file_base_name)
        file_info = nil

        @global_mutex.synchronize do
          file_info = dir_info.files[file_base_name]
          if (file_info == nil)
            file_info = FileInfo.new
            dir_info.files[file_base_name] = file_info
          end
        end

        return file_info
      end

      # Remove every FileInfo that is not part of the given list.
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The directory info to complete
      # * *lst_file_base_names* (<em>list<String></em>): The file base names to keep
      def keep_file_infos(dir_info, lst_file_base_names)
        @global_mutex.synchronize do
          if (lst_file_base_names.empty?)
            dir_info.files.clear
          else
            dir_info.files.delete_if { |file_base_name, file_info| (!lst_file_base_names.include?(file_base_name)) }
          end
        end
      end

      private

      FILE_SEPARATOR_REGEXP = Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)

      # Get the directory info of a given directory.
      # This method is not protected by the mutex.
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The corresponding directory info, or nil if none
      def dir_info_unprotected(dir_name)
        dir_info = @dirs_info

        dir_name.split(FILE_SEPARATOR_REGEXP).each do |dir_base_name|
          dir_info = dir_info.sub_dirs[dir_base_name]
          break if (dir_info == nil)
        end

        return dir_info
      end

      # Create a directory info for a given directory if it does not exist already.
      # This method is not protected by the mutex.
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to look for
      # Result::
      # * _DirInfo_: The corresponding directory info (can be the existing or a new one)
      def get_or_create_dir_info_unprotected(dir_name)
        dir_info = @dirs_info

        dir_name.split(FILE_SEPARATOR_REGEXP).each do |dir_base_name|
          dir_info.sub_dirs[dir_base_name] = Model::DirInfo.new if (dir_info.sub_dirs[dir_base_name] == nil)
          dir_info = dir_info.sub_dirs[dir_base_name]
        end

        return dir_info
      end

    end

  end

end
