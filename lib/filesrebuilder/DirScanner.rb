require 'zlib'
require 'ioblockreader'
require 'filesrebuilder/DirScanJob'
require 'filesrebuilder/FilesScanner'
#require 'fileshunter'

module FilesRebuilder

  # Responsible for scanning directories.
  # Run in the background.
  class DirScanner

    # Number of FilesScanner threads
    NBR_FILES_SCANNER_THREADS = 4

    # Max memory (in bytes) each FilesScanner thread should use with IOBlockReader
    FILES_SCANNER_BLOCK_SIZE = 64*1048576

    # Constructor
    #
    # Parameters::
    # * *data* (_Data_): The data to update upon scan
    # * *gui_controller* (_GUIController_): The GUI Controller
    def initialize(data, gui_controller)
      @data = data
      @gui_controller = gui_controller
      @exiting = false
      @files_scanner_threads = []
      @dirs_reader_thread = nil
      # Mutex protecting the list of directories
      @dirs_to_scan_mutex = Mutex.new
      # The list of directories to scan
      # list< [ DirName, ForceScan?, SourceDir? ] >
      @dirs_to_scan = []
      # Mutex protecting access to @scan_jobs
      @scan_jobs_mutex = Mutex.new
      # The list of currently active DirScanJob, per directory name
      @scan_jobs = {}
    end

    # Replace data with new one
    # !!! It is the responsibility of the caller to first stop any scan (calling cancel_all_scans) before calling this method.
    #
    # Parameters::
    # * *new_data* (<em>Model::Data</em>): The new data
    def replace_data(new_data)
      @data = new_data
    end

    # Run the scanner
    def run
      @exiting = false
      # This thread reads files to be scanned.
      # Therefore progression is accurate.
      @dirs_reader_thread = Thread.new do
        while (!@exiting)
          # Get the next dir to scan
          if (!@dirs_to_scan.empty?)
            dir_name = nil
            force_scan = nil
            src_dir = nil
            @dirs_to_scan_mutex.synchronize do
              dir_name, force_scan, src_dir = @dirs_to_scan.shift
            end
            add_dir_to_be_scanned(dir_name, :force_scan => force_scan, :src_dir => src_dir)
          end
          sleep(0.1)
        end
      end
      # Spawn FilesScanner threads
      NBR_FILES_SCANNER_THREADS.times do |idx_files_scanner|
        files_scanner = FilesScanner.new(self, FILES_SCANNER_BLOCK_SIZE)
        files_scanner.run
        @files_scanner_threads << files_scanner
      end
    end

    # Cancel scan.
    # This will empty the files list to be scanned.
    #
    # Parameters::
    # * *dir_name* (_String_): The directory to cancel scan for
    def cancel_scan(dir_name)
      @scan_jobs_mutex.synchronize do
        @scan_jobs.delete(dir_name)
      end
      # Update the GUI in a thread-safe way
      @gui_controller.thread_invalidate_dirline_for(dir_name)
      @gui_controller.notify("Directory #{dir_name} scan cancelled.")
    end

    # Cancel all scans.
    def cancel_all_scans
      @files_scanner_threads.each do |file_scanner_thread|
        file_scanner_thread.cancel_scan
      end
      @scan_jobs_mutex.synchronize do
        @scan_jobs.clear
      end
      # Update the GUI in a thread-safe way
      @gui_controller.thread_invalidate_all_dirlines
      @gui_controller.notify('All scans cancelled.')
    end

    # Exit the scanner.
    # This is called when the application exits.
    def exit
      cancel_all_scans
      @exiting = true
      @files_scanner_threads.each do |file_scanner_thread|
        file_scanner_thread.exit
      end
      @dirs_reader_thread.join
    end

    # Add a directory to scan
    #
    # Parameters::
    # * *dir_name* (_String_): Directory name
    # * *force_scan* (_Boolean_): Do we force scan? [default = false]
    # * *src_dir* (_Boolean_): Is the directory to be scanned a source directory? [default = true]
    def add_dir_to_scan(dir_name, force_scan = false, src_dir = true)
      @dirs_to_scan_mutex.synchronize do
        @dirs_to_scan << [ dir_name, force_scan, src_dir ]
      end
    end

    # Return a copy of the current scan jobs
    #
    # Result::
    # * <em>map<String,DirScanJob></em>: A copy of the scan jobs
    def get_scan_jobs_copy
      scan_jobs = nil

      @scan_jobs_mutex.synchronize do
        scan_jobs = @scan_jobs.clone
      end

      return scan_jobs
    end

    # Notify that a scan has finished
    #
    # Parameters::
    # * *scan_job* (_DirScanJob_): The scan job that has terminated
    def finished_scan(scan_job)
      dir_name = nil
      @scan_jobs_mutex.synchronize do
        @scan_jobs.each do |select_dir_name, select_scan_job|
          if (select_scan_job == scan_job)
            dir_name = select_dir_name
            break
          end
        end
        @scan_jobs.delete(dir_name)
      end
      # Update the GUI in a thread-safe way
      @gui_controller.thread_invalidate_dirline_for(dir_name)
      @gui_controller.notify("Directory #{dir_name} scanned successfully.")
    end

    # Find a scan job for the given directory
    #
    # Parameters::
    # * *dir_name* (_String_): The directory we are looking for
    # Result::
    # * _DirScanJob_: The corresponding DirScanJob, or nil if none found.
    def find_scan_job(dir_name)
      scan_job = nil

      @scan_jobs_mutex.synchronize do
        scan_job = @scan_jobs[dir_name]
      end

      return scan_job
    end

    private

    # Register a new directory to be scanned.
    # Creates a DirScanJob and make it available to scanner threads.
    # This is called from the @dirs_reader_thread thread.
    #
    # Parameters::
    # * *dir_name* (_String_): Directory to scan
    # * *options* (<em>map<Symbol,Object></em>): Addition options [default = {}]
    #   * *:force_scan* (_Boolean_): Do we scan files and directories that have already been scanned? [default = false]
    #   * *:src_dir* (_Boolean_): Is the directory a source directory? [default = true]
    def add_dir_to_be_scanned(dir_name, options = {})
      # Parse options
      force_scan = (options.has_key?(:force_scan) ? options[:force_scan] : false)
      src_dir = (options.has_key?(:src_dir) ? options[:src_dir] : true)
      absolute_dir_name = File.expand_path(dir_name)
      puts "[DirScanner] - Registering directory #{absolute_dir_name} to be scanned..."
      @gui_controller.notify("Registering directory #{absolute_dir_name} to be scanned...")
      root_dir_info = @data.get_or_create_dir_info(absolute_dir_name)
      # Get the list of files to parse
      file_infos = prepare_data_dir(absolute_dir_name, root_dir_info, force_scan)
      if (file_infos.empty?)
        @gui_controller.notify("No file to be scanned in #{absolute_dir_name}.")
      else
        dir_scan_job = DirScanJob.new(file_infos, (src_dir ? @data.src_indexes : @data.dst_indexes) )
        # Make it available for FilesScanner threads
        @scan_jobs_mutex.synchronize do
          @scan_jobs[dir_name] = dir_scan_job
        end
        # Update the GUI in a thread-safe way
        @gui_controller.thread_invalidate_dirline_for(dir_name)
      end
    end

    # Prepare data for directory scan.
    # This updates all DirInfo and FileInfo (removes extra ones and adds new ones).
    # New FileInfo added are empty, and registered to be scanned by the scanner thread.
    #
    # Parameters::
    # * *dir_name* (_String_): The directory name in absolute form
    # * *dir_info* (_DirInfo_): DirInfo structure of the directory to be prepared (corresponding to dir_name)
    # * *overwrite_existing_file_info* (_Boolean_): Do we prepare file info even if it is already present?
    # Result::
    # * <em>map<String,FileInfo></em>: The map of files to be scanned and their corresponding FileInfo
    def prepare_data_dir(dir_name, dir_info, overwrite_existing_file_info)
      # Map of files found and to be parsed, with their corresponding FileInfo (can be filled or not)
      # map< AbsoluteFileName, FileInfo >
      local_file_infos = {}

      lst_file_base_names = []
      begin
        Dir.foreach(dir_name) do |file_base_name|
          if ((file_base_name != '.') and
              (file_base_name != '..'))
            absolute_file_name = "#{dir_name}/#{file_base_name}"
            if (File.directory?(absolute_file_name))
              # Get the corresponding DirInfo
              subdir_info = @data.get_or_create_subdir_info(dir_info, file_base_name)
              local_file_infos.merge!(prepare_data_dir(absolute_file_name, subdir_info, overwrite_existing_file_info))
            else
              # We have a file
              lst_file_base_names << file_base_name
              # Get the corresponding FileInfo
              file_info = @data.get_or_create_file_info(dir_info, file_base_name)
              if (overwrite_existing_file_info or
                  (!file_info.filled))
                # We want to scan this file
                local_file_infos[absolute_file_name] = file_info
              end
            end
          end
        end
        # Delete all FileInfo that are not in the directory anymore (deleted files)
        @data.keep_file_infos(dir_info, lst_file_base_names)
      rescue
        puts "[DirScanner] - Exception while parsing #{dir_name}: #{$!}\n#{$!.backtrace.join("\n")}"
        @gui_controller.notify("Error while scanning #{dir_name}: #{$!}")
      end

      return local_file_infos
    end

  end

end
