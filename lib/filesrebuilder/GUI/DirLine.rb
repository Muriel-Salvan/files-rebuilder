module FilesRebuilder

  module GUI

    module DirLine

      def on_scan_button_clicked(widget)
        @gui_controller.scan_dir(get_dir_name, false)
      end

      def on_force_scan_button_clicked(widget)
        @gui_controller.scan_dir(get_dir_name, true)
      end

      def on_cancel_button_clicked(widget)
        @gui_controller.cancel_scan(get_dir_name)
      end

      def on_delete_button_clicked(widget)
        dir_name = get_dir_name
        @gui_controller.cancel_scan(dir_name)
        @gui_controller.delete_dirline(dir_name)
      end

      def on_view_button_clicked(widget)
        @gui_controller.display_dir_content(get_dir_name)
      end

      # Update the DirLine appearance: icon, visible buttons...
      #
      # Parameters::
      # * *dir_info* (_DirInfo_): The model associated to this DirLine
      # * *scan_job* (_DirScanJob_): The scan job associated to this DirLine
      def update_dirline_appearance(dir_info, scan_job)
        # Icon
        @builder['icon_image'].stock = (scan_job != nil) ? Gtk::Stock::FIND : ((dir_info == nil) ? Gtk::Stock::CANCEL : Gtk::Stock::APPLY)
        # Progress bar
        @builder['progressbar'].visible = (scan_job != nil)
        # Cancel button
        @builder['cancel_button'].visible = (scan_job != nil)
        # Scan button
        @builder['scan_button'].label = (dir_info == nil) ? 'Scan' : 'Re-scan'
        @builder['scan_button'].visible = (scan_job == nil)
        # Force scan button
        @builder['force_scan_button'].visible = ((dir_info != nil) and (scan_job == nil))
        # View button
        @builder['view_button'].visible = (dir_info != nil)
      end

      # Get dir_name from a widget from the button bar
      #
      # Result::
      # * _String_: The directory name
      def get_dir_name
        return @builder['dir_label'].text
      end

      # Set the directory of this DirLine
      #
      # Parameters::
      # * *dir_name* (_String_): The directory to set
      def set_dir_name(dir_name)
        @builder['dir_label'].label = dir_name
      end

      # Get the progress bar widget
      #
      # Result::
      # * <em>Gtk::Widget</em>: The progress bar
      def get_progress_bar
        return @builder['progressbar']
      end

    end

  end

end
