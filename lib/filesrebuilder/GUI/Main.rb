module FilesRebuilder

  module GUI

    class Main < GUIHandler

      # Constructor
      def initialize(gui_factory, gui_controller)
        super
        @filter = Gtk::FileFilter.new
        @filter.name = 'FilesRebuilder saved files (*.rfr)'
        @filter.add_pattern('*.rfr')
      end

      def on_main_window_destroy
        @gui_controller.exit
      end

      def on_add_dest_dir_button_clicked
        # Choose a directory
        dir_chooser = Gtk::FileChooserDialog.new('Choose a directory to rebuild',
          nil, # TODO: Set parent
          Gtk::FileChooser::ACTION_SELECT_FOLDER,
          nil,
          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT],
          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
        dir_chooser.run do |response|
          if (response == Gtk::Dialog::RESPONSE_ACCEPT)
            # Create a new line
            @gui_controller.add_new_dest_dirline(dir_chooser.filename)
          end
          dir_chooser.destroy
        end
      end

      def on_add_src_dir_button_clicked
        # Choose a directory
        dir_chooser = Gtk::FileChooserDialog.new('Choose a directory to rebuild',
          nil, # TODO: Set parent
          Gtk::FileChooser::ACTION_SELECT_FOLDER,
          nil,
          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT],
          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
        dir_chooser.run do |response|
          if (response == Gtk::Dialog::RESPONSE_ACCEPT)
            # Create a new line
            @gui_controller.add_new_src_dirline(dir_chooser.filename)
          end
          dir_chooser.destroy
        end
      end

      def on_new_menuitem_activate
        @gui_controller.reset_session
      end

      def on_save_as_menuitem_activate
        # Choose a file
        file_chooser = Gtk::FileChooserDialog.new('Save file as...',
          nil, # TODO: Set parent
          Gtk::FileChooser::ACTION_SAVE,
          nil,
          [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_ACCEPT],
          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
        file_chooser.do_overwrite_confirmation = true
        file_chooser.add_filter(@filter)
        file_chooser.run do |response|
          if (response == Gtk::Dialog::RESPONSE_ACCEPT)
            # Save our model into a file
            file_name = file_chooser.filename
            file_name.concat('.rfr') if (File.extname(file_name).empty?)
            @gui_controller.save_to_file(file_name)
          end
          file_chooser.destroy
        end
      end

      def on_open_menuitem_activate
        # Choose a file
        file_chooser = Gtk::FileChooserDialog.new('Open file...',
          nil, # TODO: Set parent
          Gtk::FileChooser::ACTION_OPEN,
          nil,
          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT],
          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL])
        file_chooser.add_filter(@filter)
        file_chooser.run do |response|
          if (response == Gtk::Dialog::RESPONSE_ACCEPT)
            # Save our model into a file
            @gui_controller.load_from_file(file_chooser.filename)
          end
          file_chooser.destroy
        end
      end

      def on_save_menuitem_activate
        @gui_controller.save_to_file
      end

      def on_quit_menuitem_activate
        @gui_controller.exit
      end

      # Set the title of the main window
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *title* (_String_): Title
      def set_title(widget, title)
        widget.title = title
      end

      # Enable save functionnality
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *enable* (_Boolean_): Is the Save functionality enabled?
      def enable_save(widget, enable)
        get_save_menuitem(widget).sensitive = enable
      end

      # Notify a message to the user, using the statusbar
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *message* (_String_): Message to notify
      def notify_status(widget, message)
        status_bar = get_status_bar(widget)
        status_bar.push(status_bar.get_context_id(''), message)
      end

      # Get the list of destination DirLines
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # <em>list<Gtk::Widget></em>: The list of DirLines
      def get_dest_dirlines(widget)
        return get_dest_dirlines_vbox(widget).children
      end

      # Add a new DirLine for destination
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to add
      def add_dest_dirline(widget, dirline_widget)
        get_dest_dirlines_vbox(widget).child = dirline_widget
      end

      # Remove a destination DirLine
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to remove
      def remove_dest_dirline(widget, dirline_widget)
        get_dest_dirlines_vbox(widget).remove(dirline_widget)
      end

      # Remove all DirLines
      def remove_all_dirlines(widget)
        dirlines_container = get_dest_dirlines_vbox(widget)
        dirlines_container.children.each do |dirline_widget|
          dirlines_container.remove(dirline_widget)
        end
      end

      # Get the list of source DirLines
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # <em>list<Gtk::Widget></em>: The list of DirLines
      def get_src_dirlines(widget)
        return get_src_dirlines_vbox(widget).children
      end

      # Add a new DirLine for source
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to add
      def add_src_dirline(widget, dirline_widget)
        get_src_dirlines_vbox(widget).child = dirline_widget
      end

      # Remove a source DirLine
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to remove
      def remove_src_dirline(widget, dirline_widget)
        get_src_dirlines_vbox(widget).remove(dirline_widget)
      end

      private

      # Get the destination DirLines VBox
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # <em>Gtk::Widget</em>: The VBox
      def get_dest_dirlines_vbox(widget)
        return widget.children[0].children[2].children[0].children[0].children[0].children[0]
      end

      # Get the source DirLines VBox
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # <em>Gtk::Widget</em>: The VBox
      def get_src_dirlines_vbox(widget)
        return widget.children[0].children[2].children[1].children[0].children[0].children[0]
      end

      # Get the statusbar
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # <em>Gtk::Widget</em>: The status bar
      def get_status_bar(widget)
        return widget.children[0].children[3]
      end

      # Get the Save menu item
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The widget
      # Result::
      # <em>Gtk::Widget</em>: The Save menu item
      def get_save_menuitem(widget)
        return widget.children[0].children[0].children[0].submenu.children[2]
      end

    end

  end

end
