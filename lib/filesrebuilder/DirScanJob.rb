module FilesRebuilder

  # Stores the data associated to a directory scan (corresponding to 1 DirLine in the GUI).
  # Thread-safe.
  # Each job might be used by several FilesScanner threads.
  class DirScanJob

    attr_reader :nbr_files_scanner
    attr_reader :dir_name

    # Constructor
    #
    # Parameters::
    # * *files_to_scan* (<em>map<String,FileInfo></em>): The set of files to be scanned for this job
    def initialize(files_to_scan)
      @files_to_scan = files_to_scan
      # Number of FilesScanner threads scanning a file from this DirScanJob
      @nbr_files_scanner = 0
      # Mutex protecting access to @files_to_scan and @nbr_files_scanner
      @files_to_scan_mutex = Mutex.new
      # Variables tracking progression
      @begin_scan_time = Time.now
      @nbr_bytes_to_scan = 0
      @files_to_scan.keys.each do |absolute_file_name|
        @nbr_bytes_to_scan += File.size(absolute_file_name)
      end
      @nbr_bytes_scanned = 0
      @nbr_bytes_partial_file = 0
      @nbr_bytes_partial_file_scanned = 0
      # Mutex protecting access to @nbr_bytes_scanned
      @progress_mutex = Mutex.new
    end

    # Get a file to be scanned
    #
    # Result::
    # * _String_: File name to be scanned (nil if none)
    # * _FileInfo_: Corresponding FileInfo to fill (nil if none)
    def get_file_to_scan
      absolute_file_name = nil
      file_info = nil

      @files_to_scan_mutex.synchronize do
        absolute_file_name, file_info = @files_to_scan.shift
        if (absolute_file_name != nil)
          @nbr_files_scanner += 1
        end
      end

      return absolute_file_name, file_info
    end

    # Notify that a file has been scanned
    #
    # Parameters::
    # * *absolute_file_name* (_String_): File name scanned
    # * *file_info* (_FileInfo_): Its corresponding FileInfo
    # Result::
    # * _Boolean_: Is this job finished?
    def file_scanned(absolute_file_name, file_info)
      @progress_mutex.synchronize do
        @nbr_bytes_scanned += file_info.size
      end
      job_finished = false
      # Check if this Job is finished
      @files_to_scan_mutex.synchronize do
        @nbr_files_scanner -= 1
        job_finished = ((@nbr_files_scanner == 0) and (@files_to_scan.empty?))
      end

      return job_finished
    end

    # Notify the current file's progression
    #
    # Parameters::
    # * *nbr_bytes* (_Fixnum_): Number of bytes for current file
    # * *nbr_bytes_scanned* (_Fixnum_): Number of scanned bytes for current file
    def partial_file_scanned(nbr_bytes, nbr_bytes_scanned)
      @nbr_bytes_partial_file = nbr_bytes
      @nbr_bytes_partial_file_scanned = nbr_bytes_scanned
    end

    # Get the progress of this job
    #
    # Result::
    # * _Fixnum_: Progression end
    # * _Fixnum_: Current progression
    # * _Fixnum_: Total number of seconds
    # * _Fixnum_: Elapsed number of seconds
    def get_progress
      elapsed_time = Time.now - @begin_scan_time
      nbr_bytes_scanned = nil
      @progress_mutex.synchronize do
        nbr_bytes_scanned = @nbr_bytes_scanned
      end
      total_time = (nbr_bytes_scanned == 0) ? 0 : (elapsed_time*@nbr_bytes_to_scan)/nbr_bytes_scanned
      return @nbr_bytes_to_scan, nbr_bytes_scanned + @nbr_bytes_partial_file_scanned, total_time, elapsed_time
    end

  end

end
