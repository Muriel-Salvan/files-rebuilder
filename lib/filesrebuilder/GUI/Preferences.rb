module FilesRebuilder

  module GUI

    module Preferences

      def on_close_button_clicked(button_widget)
        self.destroy
      end

      def on_apply_button_clicked(button_widget)
        # Minimal score filter
        @options[:score_min] = @builder['score_min_spinbutton'].value_as_int
        # Gui names filter
        gui_names_filter = []
        all_active = true
        @builder['gui_names_vbox'].each do |check_button|
          if check_button.active?
            gui_names_filter << check_button.label
          else
            all_active = false
          end
        end
        @options[:gui_names_filter] = (all_active ? nil : gui_names_filter)
      end

      # Set options to be populated in the widget
      #
      # Parameters::
      # * *options* (<em>map<Symbol,Object></em>): The options
      def set_options(options)
        @options = options
        # Fill the GUI from options
        # Minimal score filter
        spin_widget = @builder['score_min_spinbutton']
        spin_widget.set_range(0, 100)
        spin_widget.set_increments(1, 10)
        spin_widget.value = @options[:score_min]
        # Gui names filter
        Dir.glob("#{File.dirname(__FILE__)}/DisplayFile/*.glade").each do |file_name|
          gui_name = File.basename(file_name)[0..-7]
          check_button = Gtk::CheckButton.new(gui_name)
          check_button.active = ((@options[:gui_names_filter] == nil) or (@options[:gui_names_filter].include?(gui_name)))
          @builder['gui_names_vbox'].child = check_button
        end
        @builder['gui_names_vbox'].show_all
      end

    end

  end

end
