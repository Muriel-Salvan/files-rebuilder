require 'fileshunter'

module FilesHunter

  class SegmentsAnalyzer

    def set_scan_job(scan_job)
      @scan_job = scan_job
    end

    def new_add_bytes_decoded(nbr_bytes)
      self.old_add_bytes_decoded(nbr_bytes)
      @scan_job.partial_file_scanned(*self.progression)
    end
    alias :old_add_bytes_decoded :add_bytes_decoded
    alias :add_bytes_decoded :new_add_bytes_decoded

  end

end


module FilesRebuilder

  # Scan files from a common list. Thread-safe.
  class FilesScanner

    # Constructor
    #
    # Parameters::
    # * *dir_scanner* (_DirScanner_): The directory scanner, holding the list of scan jobs.
    # * *block_size* (_Fixnum_): Block size used to scan files
    def initialize(dir_scanner, block_size)
      @dir_scanner = dir_scanner
      @block_size = block_size
      @scanner_thread = nil
      @exiting = false
    end

    # Run the scanner
    def run
      @scanner_thread = Thread.new do
        # Get a Segments Analyzer
        Thread.current[:segments_analyzer] = FilesHunter::get_segments_analyzer(:block_size => @block_size)
        while (!@exiting)
          # Get the next file to scan
          scan_job, absolute_file_name, file_info = get_file_to_scan
          if (scan_job != nil)
            # We are sure to have exclusivity on this file
            Thread.current[:segments_analyzer].set_scan_job(scan_job)
            scan_file(absolute_file_name, file_info, scan_job.index)
            job_finished = scan_job.file_scanned(absolute_file_name, file_info)
            @dir_scanner.finished_scan(scan_job) if (job_finished)
          end
          sleep(0.1)
        end
      end
    end

    # Cancel current scan (can be called by an external thread)
    def cancel_scan
      @scanner_thread[:segments_analyzer].cancel_parsing
    end

    # Exit the scanner.
    # This is called when the application exits.
    def exit
      cancel_scan
      @exiting = true
      @scanner_thread.join
    end

    private

    # Get a file to scan.
    # This method ensures that no other FilesScanner thread will process this file.
    #
    # Result::
    # * _DirScanJob_: The scan job from which the file to scan is taken (nil if none)
    # * _String_: Absolute file name to scan (nil if none)
    # * _FileInfo_: Corresponding file info (nil if none)
    def get_file_to_scan
      # First select the DirScanJob we want to get a file from
      scan_jobs = @dir_scanner.get_scan_jobs_copy
      selected_scan_job = nil
      absolute_file_name = nil
      file_info = nil
      if (!scan_jobs.empty?)
        # Take the job that has less FilesScanner threads already
        scan_jobs.values.sort { |scan_job_1, scan_job_2| scan_job_1.nbr_files_scanner <=> scan_job_2.nbr_files_scanner }.each do |scan_job|
          # Choose a file in this scan job
          absolute_file_name, file_info = scan_job.get_file_to_scan
          if (absolute_file_name != nil)
            selected_scan_job = scan_job
            break
          end
        end
      end

      return selected_scan_job, absolute_file_name, file_info
    end

    # Scan a file.
    #
    # Parameters::
    # * *absolute_file_name* (_String_): File name
    # * *file_info* (_FileInfo_): File info to fill
    # * *index* (_Index_): Index to be updated
    def scan_file(absolute_file_name, file_info, index)
      puts "[FilesScanner] - Scan file #{absolute_file_name}..."
      begin
        # Get generic properties
        file_stat = File.stat(absolute_file_name)
        file_info.size = file_stat.size
        file_info.date = file_stat.mtime
        file_info.crc_list = get_file_crc(absolute_file_name)
        # Get format specific ones
        file_info.segments = Thread.current[:segments_analyzer].get_segments(absolute_file_name)
        # If there is just 1 segment, use the already computed crc_list
        if (file_info.segments.size == 1)
          file_info.segments[0].crc_list = file_info.crc_list
        else
          # Need to compute crc_list for each segment
          file_info.segments.each do |segment|
            lst_crc = []
            File.open(absolute_file_name, 'rb') do |file|
              IOBlockReader::init(file, :block_size => Model::FileInfo::CRC_BLOCK_SIZE).each_block(segment.begin_offset..segment.end_offset-1) do |data_block|
                lst_crc << Zlib.crc32(data_block, 0).to_s(16).upcase
              end
            end
            segment.crc_list = lst_crc
          end
        end
        # Add indexes
        index.add(absolute_file_name, file_info)
        # Everything went fine
        file_info.filled = true
      rescue
        puts "!!! Unable to scan file #{absolute_file_name}: #{$!}\n#{$!.backtrace.join("\n")}"
      end
    end

    # Get a file CRC values
    #
    # Parameters:
    # * *file_name* (_String_): File name to get CRC from
    # Result:
    # * <em>list<String></em>: The list of CRCs by block of Model::FileInfo::CRC_BLOCK_SIZE
    def get_file_crc(file_name)
      lst_crc = []

      File.open(file_name, 'rb') do |file|
        IOBlockReader::init(file, :block_size => Model::FileInfo::CRC_BLOCK_SIZE).each_block do |data_block|
          lst_crc << Zlib.crc32(data_block, 0).to_s(16).upcase
        end
      end

      return lst_crc
    end

  end

end
