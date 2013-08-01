module FilesRebuilder

  module GUI

    class DirLine < GUIHandler

      def on_scan_button_clicked(widget)
        @gui_controller.scan_dir(get_dir_name_from_button(widget))
      end

      def on_force_scan_button_clicked(widget)
        @gui_controller.scan_dir(get_dir_name_from_button(widget), true)
      end

      def on_cancel_button_clicked(widget)
        @gui_controller.cancel_scan(get_dir_name_from_button(widget))
      end

      def on_delete_button_clicked(widget)
        dir_name = get_dir_name(widget.parent)
        @gui_controller.cancel_scan(dir_name)
        @gui_controller.delete_dirline(dir_name)
      end

      def on_view_button_clicked(widget)
        @gui_controller.display_dir_content(get_dir_name_from_button(widget))
      end

      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *dir_info* (_DirInfo_): The model associated to this DirLine
      # * *scan_job* (_DirScanJob_): The scan job associated to this DirLine
      def update_dirline_appearance(widget, dir_info, scan_job)
        c = widget.children
        c3c = c[3].children
        # Icon
        c[1].stock = (scan_job != nil) ? Gtk::Stock::FIND : ((dir_info == nil) ? Gtk::Stock::CANCEL : Gtk::Stock::APPLY)
        # Progress bar
        c[2].visible = (scan_job != nil)
        # Cancel button
        c3c[0].visible = (scan_job != nil)
        # Scan button
        c3c[1].label = (dir_info == nil) ? 'Scan' : 'Re-scan'
        c3c[1].visible = (scan_job == nil)
        # Force scan button
        c3c[2].visible = ((dir_info != nil) and (scan_job == nil))
        # View button
        c3c[3].visible = (dir_info != nil)
      end

      # Get dir_name from a widget from the button bar
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # * _String_: The directory name
      def get_dir_name(widget)
        return widget.children[0].text
      end

      # Set the directory of this DirLine
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *dir_name* (_String_): The directory to set
      def set_dir_name(widget, dir_name)
        widget.children[0].label = dir_name
      end

      # Get the progress bar widget
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # * <em>Gtk::Widget</em>: The progress bar
      def get_progress_bar(widget)
        return widget.children[2]
      end

      private

      # Get dir_name from a widget from the button bar
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # * _String_: The directory name
      def get_dir_name_from_button(widget)
        return get_dir_name(widget.parent.parent)
      end

    end

  end

end
