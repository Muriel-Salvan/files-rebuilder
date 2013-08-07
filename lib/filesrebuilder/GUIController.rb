require 'zlib'

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
      main_handler = @gui_factory.get_gui_handler('Main')
      dirline_handler = @gui_factory.get_gui_handler('DirLine')
      Gtk.timeout_add(100) do
        (main_handler.get_dest_dirlines(@main_widget) + main_handler.get_src_dirlines(@main_widget)).each do |dirline_widget|
          # Only consider visible progress bars
          progress_bar_widget = dirline_handler.get_progress_bar(dirline_widget)
          if (progress_bar_widget.visible?)
            # Get corresponding DirScanJob
            scan_job = @dir_scanner.find_scan_job(dirline_handler.get_dir_name(dirline_widget))
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
      @gui_factory.get_gui_handler('DirLine').set_dir_name(new_widget, dir_name)
      @gui_factory.get_gui_handler('Main').add_dest_dirline(@main_widget, new_widget)
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
      @gui_factory.get_gui_handler('DirLine').set_dir_name(new_widget, dir_name)
      @gui_factory.get_gui_handler('Main').add_src_dirline(@main_widget, new_widget)
      # Update the dirline based on our data
      update_dirline(new_widget)
    end

    # Delete the DirLine for the given directory
    #
    # Parameters::
    # * *dir_name* (_String_): Directory
    def delete_dirline(dir_name)
      main_handler = @gui_factory.get_gui_handler('Main')
      dirline_handler = @gui_factory.get_gui_handler('DirLine')
      found = false
      main_handler.get_dest_dirlines(@main_widget).each do |dest_dirline|
        if (dirline_handler.get_dir_name(dest_dirline) == dir_name)
          # Remove all previously indexed fileinfo
          @data.dst_indexes.remove(@data.get_file_info_from_dir(dir_name)) if (!found)
          main_handler.remove_dest_dirline(@main_widget, dest_dirline)
          found = true
        end
      end
      found = false
      main_handler.get_src_dirlines(@main_widget).each do |src_dirline|
        if (dirline_handler.get_dir_name(src_dirline) == dir_name)
          # Remove all previously indexed fileinfo
          @data.src_indexes.remove(@data.get_file_info_from_dir(dir_name)) if (!found)
          main_handler.remove_src_dirline(@main_widget, src_dirline)
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
      dirline_handler = @gui_factory.get_gui_handler('DirLine')
      dir_name = dirline_handler.get_dir_name(dirline_widget)
      # Check if a scan job is associated to it
      scan_job = @dir_scanner.find_scan_job(dir_name)
      # Get the associated dir_info
      dir_info = @data.dir_info(dir_name)

      dirline_handler.update_dirline_appearance(dirline_widget, dir_info, scan_job)
    end

    # Update all dirlines
    def update_dirlines
      # Loop on all dirline widgets
      main_handler = @gui_factory.get_gui_handler('Main')
      (main_handler.get_dest_dirlines(@main_widget) + main_handler.get_src_dirlines(@main_widget)).each do |dirline_widget|
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
      main_handler = @gui_factory.get_gui_handler('Main')
      dirline_handler = @gui_factory.get_gui_handler('DirLine')
      (main_handler.get_dest_dirlines(@main_widget) + main_handler.get_src_dirlines(@main_widget)).each do |dirline_widget|
        if (dirline_handler.get_dir_name(dirline_widget) == dir_name)
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
      main_handler = @gui_factory.get_gui_handler('Main')
      (main_handler.get_dest_dirlines(@main_widget) + main_handler.get_src_dirlines(@main_widget)).each do |dirline_widget|
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
      main_handler = @gui_factory.get_gui_handler('Main')
      dirline_handler = @gui_factory.get_gui_handler('DirLine')
      main_handler.get_src_dirlines(@main_widget).each do |dirline_widget|
        if (dirline_handler.get_dir_name(dirline_widget) == dir_name)
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
      show_dir_handler = @gui_factory.get_gui_handler('ShowDir')
      show_dir_handler.set_dir_name(new_widget, dir_name, @data.dir_info(dir_name))
      new_widget.show
    end

    # Exit all processing.
    # This is called when the application exits.
    def exit
      @dir_scanner.exit
      @exiting = true
      Gtk.main_quit
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
      @gui_factory.get_gui_handler('Main').remove_all_dirlines(@main_widget)
    end

    FILE_HEADER = 'Files_Rebuilder_Save_File'.force_encoding(Encoding::ASCII_8BIT)

    # Save data in a file
    #
    # Parameters::
    # * *file_name* (_String_): File name to save data to [default = @current_file_name]
    def save_to_file(file_name = @current_file_name)
      # Loop on all dirline widgets
      main_handler = @gui_factory.get_gui_handler('Main')
      dirline_handler = @gui_factory.get_gui_handler('DirLine')
      File.open(file_name, 'wb') do |file|
        file.write(FILE_HEADER)
        file.write(Zlib::Deflate.deflate(RubySerial::dump({
          :dest_dir_names => main_handler.get_dest_dirlines(@main_widget).map { |dirline_widget| dirline_handler.get_dir_name(dirline_widget) },
          :src_dir_names => main_handler.get_src_dirlines(@main_widget).map { |dirline_widget| dirline_handler.get_dir_name(dirline_widget) },
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
        main_handler = @gui_factory.get_gui_handler('Main')
        main_handler.notify_status(@main_widget, message)
      end
    end

    # Invalidate current loaded file.
    # This updates the following:
    # * The window's title
    # * The Save menu sensitivity
    def invalidate_current_loaded_file
      main_handler = @gui_factory.get_gui_handler('Main')
      if (@current_file_name == nil)
        main_handler.set_title(@main_widget, 'Files Rebuilder')
        main_handler.enable_save(@main_widget, false)
      else
        main_handler.set_title(@main_widget, "Files Rebuilder - #{@current_file_name}")
        main_handler.enable_save(@main_widget, true)
      end
    end

    # Get matching file info for a given file info.
    # This is done by looking at indexes.
    #
    # Parameters::
    # * *file_info* (_FileInfo_): Corresponding FileInfo
    # * *segment_index* (_Fixnum_): Segment index in this file info. Set to nil to consider all segments. [default = nil]
    # Result::
    # * _MatchingIndex_: The source index info, containing only matching files
    # * _MatchingIndex_: The destination index info, containing only matching files
    def get_matching_file_info(file_info, segment_index = nil)
      return @data.src_indexes.get_matching_file_info(file_info, segment_index), @data.dst_indexes.get_matching_file_info(file_info, segment_index)
    end

    private

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
