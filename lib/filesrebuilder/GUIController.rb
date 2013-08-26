require 'filesrebuilder/Model/MatchingInfo'
require 'filesrebuilder/PointerIterator'
require 'zlib'
require 'tmpdir'
require 'fileutils'

module FilesRebuilder

  class GUIController

    # Constructor
    #
    # Parameters::
    # * *gui_factory* (_GuiFactory_): The GUI Factory to pilot
    def initialize(gui_factory)
      @gui_factory = gui_factory
      @data = Model::Data.new
      @exiting = false
      require 'filesrebuilder/DirScanner'
      @dir_scanner = DirScanner.new(@data, self)
      # Execute the scanning thread
      Gtk.init_add do
        @dir_scanner.run
      end
      @current_file_name = nil
    end

    # Set the Main widget
    #
    # Parameters::
    # * *main_widget* (<em>Gtk::Widget</em>): Main widget
    def set_main_widget(main_widget)
      @main_widget = main_widget
      # Initialize it
      invalidate_current_loaded_file
    end

    # Run the Gtk callback that updates DirLine progress bars.
    # Call this when the main window has been created.
    def run_callback_dirline_progress_bars
      Gtk.timeout_add(100) do
        (@main_widget.get_dest_dirlines + @main_widget.get_src_dirlines).each do |dirline_widget|
          # Only consider visible progress bars
          progress_bar_widget = dirline_widget.get_progress_bar
          if (progress_bar_widget.visible?)
            # Get corresponding DirScanJob
            scan_job = @dir_scanner.find_scan_job(dirline_widget.get_dir_name)
            if (scan_job != nil)
              progression_end, progression_current, total_time, elapsed_time = scan_job.get_progress
              if (progression_end == 0)
                progress_bar_widget.fraction = 0
                progress_bar_widget.text = ''
              else
                progress_bar_widget.fraction = progression_current.to_f/progression_end
                if (total_time == 0)
                  progress_bar_widget.text = "#{(progress_bar_widget.fraction*100).to_i}%"
                else
                  progress_bar_widget.text = "#{(progress_bar_widget.fraction*100).to_i}% - #{print_time(total_time-elapsed_time)} / #{print_time(total_time)}"
                end
              end
            end
          end
        end
        next (!@exiting)
      end
    end

    # Add a new destination DirLine for the given directory
    # This method has to be called from the main Gtk thread
    #
    # Parameters::
    # * *dir_name* (_String_): Directory
    def add_new_dest_dirline(dir_name)
      new_widget = @gui_factory.new_widget('DirLine')
      new_widget.set_dir_name(dir_name)
      @main_widget.add_dest_dirline(new_widget)
      # Update the dirline based on our data
      update_dirline(new_widget)
    end

    # Add a new source DirLine for the given directory
    # This method has to be called from the main Gtk thread
    #
    # Parameters::
    # * *dir_name* (_String_): Directory
    def add_new_src_dirline(dir_name)
      new_widget = @gui_factory.new_widget('DirLine')
      new_widget.set_dir_name(dir_name)
      @main_widget.add_src_dirline(new_widget)
      # Update the dirline based on our data
      update_dirline(new_widget)
    end

    # Delete the DirLine for the given directory
    #
    # Parameters::
    # * *dir_name* (_String_): Directory
    def delete_dirline(dir_name)
      found = false
      @main_widget.get_dest_dirlines.each do |dest_dirline|
        if (dest_dirline.get_dir_name == dir_name)
          # Remove all previously indexed fileinfo
          @data.dst_indexes.remove(@data.get_file_info_from_dir(dir_name)) if (!found)
          @main_widget.remove_dest_dirline(dest_dirline)
          found = true
        end
      end
      found = false
      @main_widget.get_src_dirlines.each do |src_dirline|
        if (src_dirline.get_dir_name == dir_name)
          # Remove all previously indexed fileinfo
          @data.src_indexes.remove(@data.get_file_info_from_dir(dir_name)) if (!found)
          @main_widget.remove_src_dirline(src_dirline)
          found = true
        end
      end
    end

    # Update a dirline, based on the data we have on this directory.
    # !!! Make sure this method is called only in the main thread or Gtk callbacks as it deals with Gtk Widgets.
    # Changes the following:
    # * Hide progress bar and Cancel buttons only if no DirScanJob is associated to it
    # * Hide force scan button if there is no data for this directory or if a DirScanJob is running
    # * Hide scan button if a DirScanJob is running
    # * Rename Scan into Re-scan if there is data for this directory
    # * Hide View button if there is no data for this directory
    # * Update the icon according to data's presence
    #
    # Parameters::
    # * *dirline_widget* (<em>Gtk::Widget</em>): The dirline widget to be updated
    def update_dirline(dirline_widget)
      # Get the directory name
      dir_name = dirline_widget.get_dir_name
      # Check if a scan job is associated to it
      scan_job = @dir_scanner.find_scan_job(dir_name)
      # Get the associated dir_info
      dir_info = @data.dir_info(dir_name)
      dirline_widget.update_dirline_appearance(dir_info, scan_job)
    end

    # Update all dirlines
    def update_dirlines
      # Loop on all dirline widgets
      (@main_widget.get_dest_dirlines + @main_widget.get_src_dirlines).each do |dirline_widget|
        update_dirline(dirline_widget)
      end
    end

    # Invalidate the DirLine associated to a given directory.
    # This method should be called from secondary threads (not the main Gtk one).
    #
    # Parameters::
    # * *dir_name* (_String_): Directory to update DirLine for
    def thread_invalidate_dirline_for(dir_name)
      # Find the DirLine
      (@main_widget.get_dest_dirlines + @main_widget.get_src_dirlines).each do |dirline_widget|
        if (dirline_widget.get_dir_name == dir_name)
          Gtk::idle_add do
            update_dirline(dirline_widget)
            next false
          end
        end
      end
    end

    # Invalidate all DirLines.
    # This method should be called from secondary threads (not the main Gtk one).
    def thread_invalidate_all_dirlines
      # Find the DirLine
      (@main_widget.get_dest_dirlines + @main_widget.get_src_dirlines).each do |dirline_widget|
        Gtk::idle_add do
          update_dirline(dirline_widget)
          next false
        end
      end
    end

    # Scan a directory
    #
    # Parameters::
    # * *dir_name* (_String_): The directory to scan
    # * *force_scan* (_Boolean_): Do we force scan? [default = false]
    def scan_dir(dir_name, force_scan = false)
      # Check whether this directory is source or destination
      src_dir = false
      @main_widget.get_src_dirlines.each do |dirline_widget|
        if (dirline_widget.get_dir_name == dir_name)
          src_dir = true
          break
        end
      end
      if force_scan
        # Remove all previously indexed fileinfo
        lst_fileinfo = @data.get_file_info_from_dir(dir_name)
        src_dir ? @data.src_indexes.remove(lst_fileinfo) : @data.dst_indexes.remove(lst_fileinfo)
      end
      @dir_scanner.add_dir_to_scan(dir_name, force_scan, src_dir)
    end

    # Display the content of a directory in a new window
    #
    # Parameters::
    # * *dir_name* (_String_): The directory to display
    def display_dir_content(dir_name)
      new_widget = @gui_factory.new_widget('ShowDir')
      new_widget.set_dir_name(dir_name, @data.dir_info(dir_name))
      new_widget.show
    end

    # Exit all processing.
    # This is called when the application exits.
    def exit
      @dir_scanner.exit
      @exiting = true
      Gtk.main_quit
      clean_tmp_dir
    end

    # Cancel scan of a given directory
    #
    # Parameters::
    # * *dir_name* (_String_): The directory to cancel scan for
    def cancel_scan(dir_name)
      @dir_scanner.cancel_scan(dir_name)
    end

    # Reset the current session
    def reset_session
      # Cancels all scans if any
      @dir_scanner.cancel_all_scans
      # Delete all dirlines
      @main_widget.remove_all_dirlines
    end

    FILE_HEADER = 'Files_Rebuilder_Save_File'.force_encoding(Encoding::ASCII_8BIT)

    # Save data in a file
    #
    # Parameters::
    # * *file_name* (_String_): File name to save data to [default = @current_file_name]
    def save_to_file(file_name = @current_file_name)
      # Loop on all dirline widgets
      File.open(file_name, 'wb') do |file|
        file.write(FILE_HEADER)
        file.write(Zlib::Deflate.deflate(RubySerial::dump({
          :dest_dir_names => @main_widget.get_dest_dirlines.map { |dirline_widget| dirline_widget.get_dir_name },
          :src_dir_names => @main_widget.get_src_dirlines.map { |dirline_widget| dirline_widget.get_dir_name },
          :data => @data
        })))
      end
      notify("File #{file_name} saved correctly")
      @current_file_name = file_name
      invalidate_current_loaded_file
    end

    # Load data from a file
    #
    # Parameters::
    # * *file_name* (_String_): File name to load data from
    def load_from_file(file_name)
      # Load data
      saved_data = nil
      File.open(file_name, 'rb') do |file|
        if (file.read(FILE_HEADER.size) == FILE_HEADER)
          saved_data = RubySerial::load(Zlib::Inflate.inflate(file.read))
        else
          notify "Invalid file: #{file_name}"
        end
      end
      if (saved_data != nil)
        reset_session
        @data = saved_data[:data]
        @dir_scanner.replace_data(@data)
        # Create all dirlines
        saved_data[:dest_dir_names].each do |dir_name|
          add_new_dest_dirline(dir_name)
        end
        saved_data[:src_dir_names].each do |dir_name|
          add_new_src_dirline(dir_name)
        end
        notify("File #{file_name} loaded correctly")
        @current_file_name = file_name
        invalidate_current_loaded_file
      end
    end

    # Notify a message to the user, using the statusbar.
    # This method is thread safe.
    #
    # Parameters::
    # * *message* (_String_): Message to notify
    def notify(message)
      Gtk::idle_add do
        @main_widget.notify_status(message)
      end
    end

    # Invalidate current loaded file.
    # This updates the following:
    # * The window's title
    # * The Save menu sensitivity
    def invalidate_current_loaded_file
      if (@current_file_name == nil)
        @main_widget.title = 'Files Rebuilder'
        @main_widget.enable_save(false)
      else
        @main_widget.title = "Files Rebuilder - #{@current_file_name}"
        @main_widget.enable_save(true)
      end
    end

    # Get matching indexes for a given file info.
    # This is done by looking at indexes.
    #
    # Parameters::
    # * *file_info* (_FileInfo_): Corresponding FileInfo
    # * *segment_index* (_Fixnum_): Segment index in this file info. Set to nil to consider all segments. [default = nil]
    # Result::
    # * _MatchingIndex_: The source index info, containing only matching files
    # * _MatchingIndex_: The destination index info, containing only matching files
    def get_matching_indexes(file_info, segment_index = nil)
      return @data.src_indexes.get_matching_index(file_info, segment_index), @data.dst_indexes.get_matching_index(file_info, segment_index)
    end

    # Compare groups of source and destination directories
    #
    # Parameters::
    # * *src_reference* (_Boolean_): Is source group the reference?
    def compare_groups(src_reference)
      # Get the list of directories to compare
      # list< [ absolute_dir_name, dir_info ] >
      lst_dirs = []
      index = nil
      matching_selection = nil
      if src_reference
        @main_widget.get_src_dirlines.each do |dirline|
          dir_name = dirline.get_dir_name
          lst_dirs << [ dir_name, @data.dir_info(dir_name) ]
        end
        index = @data.dst_indexes
        matching_selection = @data.src_selection
      else
        @main_widget.get_dest_dirlines.each do |dirline|
          dir_name = dirline.get_dir_name
          lst_dirs << [ dir_name, @data.dir_info(dir_name) ]
        end
        index = @data.src_indexes
        matching_selection = @data.dst_selection
      end
      # Display CompareGroup window
      new_widget = @gui_factory.new_widget('CompareGroup')
      new_widget.set_dirs_to_compare(lst_dirs, index, matching_selection)
      new_widget.show
    end

    # Get the MatchingInfo object, recaping every matching file for a given pointer
    #
    # Parameters::
    # * *pointer* (_FileInfo_ or _SegmentPointer_): The file or segment we want matches for
    # * *index* (_Index_): Index of the data to be looked up for matching files
    # Result::
    # * _MatchingInfo_: The resulting MatchingInfo
    def get_matching_info(pointer, index)
      file_info = pointer
      idx_segment = nil
      if (pointer.is_a?(Model::SegmentPointer))
        file_info = pointer.file_info
        idx_segment = pointer.idx_segment
      end
      # Create the index subset, matching our pointer then use it to find matching files
      return Model::MatchingInfo.new(index.get_matching_index(file_info, idx_segment), pointer)
    end

    # Display a pointer comparator
    #
    # Parameters::
    # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer to be compared
    # * *matching_pointers* (<em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>): The sorted list of matching pointers, along with their matching index information
    # * *matching_selection* (_MatchingSelection_): Current user selection of matching files
    def display_pointer_comparator(pointer, matching_pointers, matching_selection)
      # Display ComparePointer window
      new_widget = @gui_factory.new_widget('ComparePointer')
      itr_pointer = PointerIterator.new
      itr_pointer.set_from_single(pointer, matching_pointers)
      new_widget.set_pointers_to_compare(itr_pointer, matching_selection, true)
      new_widget.show
    end

    # Display a dirinfo comparator.
    # This displays pointer comparators for every pointer (files first then segments) in the given dirinfo that has a minimal score (set in options) and does not have a matching pointer yet.
    #
    # Parameters::
    # * *lst_dirinfo* (<em>list<DirInfo></em>): List of dirinfo to consider
    # * *index* (_MatchingIndex_): Index of the possibly matching files
    # * *matching_selection* (_MatchingSelection_): Current user selection of matching files
    def display_dirinfo_comparator(lst_dirinfo, index, matching_selection)
      # Display ComparePointer window
      new_widget = @gui_factory.new_widget('ComparePointer')
      itr_pointer = PointerIterator.new
      itr_pointer.set_from_dirinfos(self, lst_dirinfo, index, matching_selection, @data.options[:gui_names_filter])
      new_widget.set_pointers_to_compare(itr_pointer, matching_selection, false)
      new_widget.show
    end

    # Create a widget to be used to display a pointer
    #
    # Parameters::
    # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer to be displayed
    # Result::
    # * <em>Gtk::Widget</em>: The corresponding widget
    def create_widget_for_pointer(pointer)
      new_widget = @gui_factory.new_widget("DisplayFile/#{get_gui_name_for(pointer)}")
      # Initialize the widget with the pointer's content
      if pointer.is_a?(Model::FileInfo)
        file_name = pointer.get_absolute_name
        File.open(file_name, 'rb') do |file|
          new_widget.init_with_data(pointer, IOBlockReader::init(file, :block_size => Model::FileInfo::CRC_BLOCK_SIZE), 0, File.size(file_name))
        end
      else
        file_name = pointer.file_info.get_absolute_name
        segment = pointer.segment
        File.open(file_name, 'rb') do |file|
          new_widget.init_with_data(pointer, IOBlockReader::init(file, :block_size => Model::FileInfo::CRC_BLOCK_SIZE), segment.begin_offset, segment.end_offset)
        end
      end

      return new_widget
    end

    # Create a widget to be used to display a matching pointer
    #
    # Parameters::
    # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer to be displayed
    # * *selected* (_Boolean_): Is this matching pointer selected?
    # Result::
    # * <em>Gtk::Widget</em>: The corresponding widget
    def create_widget_for_matching_pointer(pointer, selected)
      error = nil
      begin
        pointer_widget = create_widget_for_pointer(pointer)
      rescue
        error = $!.to_s
      end
      new_widget = @gui_factory.new_widget('DisplayMatchingPointer')
      new_widget.init_matching_pointers
      if (error == nil)
        new_widget.set_pointer_widget(pointer_widget)
        new_widget.add_pointer(pointer)
      else
        new_widget.add_pointer(pointer, "!!! ERROR: #{error}.")
      end
      # Add indication in the case this matching pointer is selected
      new_widget.set_selected(selected)

      return new_widget
    end

    # Open a pointer's content in the OS
    #
    # Parameters:
    # * *pointer* (_FileInfo_ or _SegmentPointer_): The pointer to open
    def open_external(pointer)
      if (pointer.is_a?(Model::FileInfo) or
          pointer.is_a?(Model::DirInfo))
        # Open the file directly
        os_open_file(pointer.get_absolute_name)
      else
        # Extract the segment in a temporary file before opening it
        tmp_file_name = "#{get_tmp_dir}/#{pointer.file_info.get_absolute_name.hash.to_s}/Seg#{pointer.idx_segment}-#{pointer.file_info.base_name}"
        segment = pointer.segment
        begin
          FileUtils::mkdir_p(File.dirname(tmp_file_name))
          File.open(tmp_file_name, 'wb') do |tmp_file|
            File.open(pointer.file_info.get_absolute_name, 'rb') do |file|
              IOBlockReader::init(file, :block_size => Model::FileInfo::CRC_BLOCK_SIZE).each_block(segment.begin_offset..segment.end_offset-1) do |data_block|
                tmp_file.write(data_block)
              end
            end
          end
          os_open_file(tmp_file_name)
        rescue
          log_err "Unable to create temporary file \"#{tmp_file_name}\" from \"#{pointer.file_info.get_absolutename}\" and open it: #{$!}."
        end
      end
    end

    # Display preferences dialog
    def display_preferences
      pref_widget = @gui_factory.new_widget('Preferences')
      pref_widget.set_options(@data.options)
      pref_widget.show
    end

    # Return global options
    #
    # Result::
    # * <em>map<Symbol,Object></em>: The options
    def options
      return @data.options
    end

    # Get the name of the GUI that is used to display the content of a given pointer
    #
    # Parameters::
    # * *pointer* (_FileInfo_ or _SegmentPointer_): The pointer to display
    # Result::
    # * _String_: The corresponding GUI name
    def get_gui_name_for(pointer)
      # Get the extensions
      if pointer.is_a?(Model::FileInfo)
        if (pointer.segments.size > 1)
          extension = :unknown
        else
          extension = pointer.segments[0].extensions[0]
        end
      else
        extension = pointer.segment.extensions[0]
      end
      # Check that this GUI component exists, otherwise switch back to :unknown
      str_extension = extension.to_s
      gui_name = "#{str_extension[0].upcase}#{str_extension[1..-1]}"
      if (!File.exist?("#{File.dirname(__FILE__)}/GUI/DisplayFile/#{gui_name}.rb"))
        log_debug "No GUI to display files of extension #{gui_name}."
        gui_name = 'Unknown'
      end
      return gui_name
    end

    private

    # Get the temporary directory name
    #
    # Result::
    # * _String_: Temporary directory name
    def get_tmp_dir
      return "#{Dir.tmpdir}/FilesRebuilder"
    end

    # Remove temporary directory
    def clean_tmp_dir
      tmp_dir_name = get_tmp_dir
      log_debug "Cleaning temporary directory #{tmp_dir_name}"
      FileUtils::rm_rf(tmp_dir_name)
    end

    # Print a number of seconds in a human-friendly way
    #
    # Parameters::
    # * *nbr_secs* (_Fixnum_): The number of seconds to display
    # Result::
    # * _String_: The corresponding human-readable form
    def print_time(nbr_secs)
      secs  = nbr_secs.to_i
      mins  = secs / 60
      hours = mins / 60
      return "#{hours}:#{sprintf('%.2d',mins % 60)}:#{sprintf('%.2d',secs % 60)}"
    end

  end

end
