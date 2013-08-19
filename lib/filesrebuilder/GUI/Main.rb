module FilesRebuilder

  module GUI

    module Main

      # Initializer called for each new widget built
      def self.extended(mod)
        @filter = Gtk::FileFilter.new
        @filter.name = 'FilesRebuilder saved files (*.rfr)'
        @filter.add_pattern('*.rfr')
      end

      def on_preferences_menuitem_activate
        @gui_controller.display_preferences
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

      def on_compare_dest_button_clicked
        @gui_controller.compare_groups(false)
      end

      def on_compare_src_button_clicked
        @gui_controller.compare_groups(true)
      end

      # Enable save functionnality
      #
      # Parameters::
      # * *enable* (_Boolean_): Is the Save functionality enabled?
      def enable_save(enable)
        @builder['save_menuitem'].sensitive = enable
      end

      # Notify a message to the user, using the statusbar
      #
      # Parameters::
      # * *message* (_String_): Message to notify
      def notify_status(message)
        status_bar = @builder['statusbar']
        status_bar.push(status_bar.get_context_id(''), message)
      end

      # Get the list of destination DirLines
      #
      # Result::
      # <em>list<Gtk::Widget></em>: The list of DirLines
      def get_dest_dirlines
        return @builder['dest_dirlines_vbox'].children
      end

      # Add a new DirLine for destination
      #
      # Parameters::
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to add
      def add_dest_dirline(dirline_widget)
        @builder['dest_dirlines_vbox'] << dirline_widget
      end

      # Remove a destination DirLine
      #
      # Parameters::
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to remove
      def remove_dest_dirline(dirline_widget)
        @builder['dest_dirlines_vbox'].remove(dirline_widget)
      end

      # Remove all DirLines
      def remove_all_dirlines
        [ @builder['dest_dirlines_vbox'], @builder['src_dirlines_vbox'] ].each do |dirlines_container|
          dirlines_container.children.each do |dirline_widget|
            dirlines_container.remove(dirline_widget)
          end
        end
      end

      # Get the list of source DirLines
      #
      # Result::
      # <em>list<Gtk::Widget></em>: The list of DirLines
      def get_src_dirlines
        return @builder['src_dirlines_vbox'].children
      end

      # Add a new DirLine for source
      #
      # Parameters::
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to add
      def add_src_dirline(dirline_widget)
        @builder['src_dirlines_vbox'] << dirline_widget
      end

      # Remove a source DirLine
      #
      # Parameters::
      # * *dirline_widget* (<em>Gtk::Widget</em>): The DirLine widget to remove
      def remove_src_dirline(dirline_widget)
        @builder['src_dirlines_vbox'].remove(dirline_widget)
      end

    end

  end

end
