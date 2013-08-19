module FilesRebuilder

  module GUI

    module DisplayMatchingPointer

      def on_select_button_clicked(button_widget)
        compare_pointer_widget = button_widget.toplevel
        if compare_pointer_widget.toplevel?
          compare_pointer_widget.select_pointer_widget(self)
        else
          raise 'Unable to find ComparePointer top-level window'
        end
      end

      def on_open_button_clicked(button_widget)
        @gui_controller.open_external(self.user_data)
      end

      # Set the pointer widget
      #
      # Parameters::
      # * *pointer_widget* (<em>Gtk::Wiget</em>): The pointer widget to assign
      def set_pointer_widget(pointer_widget)
        @builder['container_frame'] << pointer_widget
      end

      # Set the name appearing in the matching pointer widget
      #
      # Parameters::
      # * *name* (_String_): The name to be displayed
      def set_name(name)
        @builder['name_label'].label = name
      end

      # Set the selection
      #
      # Parameters::
      # * *selected* (_Boolean_): Is this matching pointer selected?
      def set_selected(selected)
        default_color = Gtk::Widget.default_style.bg(Gtk::STATE_NORMAL)
        self.modify_bg(Gtk::STATE_NORMAL, selected ? Gdk::Color.new(65535,0,0) : default_color)
        self.show
      end

      # Set the focus
      #
      # Parameters::
      # * *focused* (_Boolean_): Is this matching pointer focused?
      # * *selected* (_Boolean_): Is this matching pointer selected?
      def set_focus(focused, selected)
        default_color = Gtk::Widget.default_style.bg(Gtk::STATE_NORMAL)
        self.modify_bg(Gtk::STATE_NORMAL, (
          selected ? (
            focused ? Gdk::Color.new(65535,65535,0) : Gdk::Color.new(65535,0,0)
          ) : (
            focused ? Gdk::Color.new(0,65535,0) : default_color
          )
        ))
        self.show
      end

    end

  end

end
