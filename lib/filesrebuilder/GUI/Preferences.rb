module FilesRebuilder

  module GUI

    module Preferences

      def on_close_button_clicked(button_widget)
        self.destroy
      end

      def on_apply_button_clicked(button_widget)
        self.user_data[:score_min] = @builder['score_min_spinbutton'].value_as_int
      end

      # Set options to be populated in the widget
      #
      # Parameters::
      # * *options* (<em>map<Symbol,Object></em>): The options
      def set_options(options)
        self.user_data = options
        # Fill options
        spin_widget = @builder['score_min_spinbutton']
        spin_widget.set_range(0, 100)
        spin_widget.set_increments(1, 10)
        spin_widget.value = options[:score_min]
      end

    end

  end

end
