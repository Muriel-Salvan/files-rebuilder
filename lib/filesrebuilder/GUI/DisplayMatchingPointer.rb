module FilesRebuilder

  module GUI

    class DisplayMatchingPointer < GUIHandler

      def on_select_button_clicked(button_widget)
        compare_pointer_widget = button_widget.toplevel
        if compare_pointer_widget.toplevel?
          widget_handler = @gui_factory.get_gui_handler('ComparePointer')
          widget_handler.select_pointer_widget(compare_pointer_widget, button_widget.parent.parent.parent)
        else
          raise 'Unable to find ComparePointer top-level window'
        end
      end

      # Set the pointer widget
      #
      # Parameters::
      # * *widget* (<em>Gtk::Wiget</em>): The Display matching pointer widget
      # * *pointer_widget* (<em>Gtk::Wiget</em>): The pointer widget to assign
      def set_pointer_widget(widget, pointer_widget)
        widget.children[0].child = pointer_widget
      end

      # Set the name appearing in the matching pointer widget
      #
      # Parameters::
      # * *widget* (<em>Gtk::Wiget</em>): The Display matching pointer widget
      # * *name* (_String_): The name to be displayed
      def set_name(widget, name)
        widget.children[0].label_widget.children[1].label = name
      end

      # Set the selection
      #
      # Parameters::
      # * *widget* (<em>Gtk::Wiget</em>): The Display matching pointer widget
      # * *selected* (_Boolean_): Is this matching pointer selected?
      def set_selected(widget, selected)
        default_color = Gtk::Widget.default_style.bg(Gtk::STATE_NORMAL)
        widget.modify_bg(Gtk::STATE_NORMAL, selected ? Gdk::Color.new(65535,0,0) : default_color)
        widget.show
      end

      # Set the focus
      #
      # Parameters::
      # * *widget* (<em>Gtk::Wiget</em>): The Display matching pointer widget
      # * *focused* (_Boolean_): Is this matching pointer focused?
      # * *selected* (_Boolean_): Is this matching pointer selected?
      def set_focus(widget, focused, selected)
        default_color = Gtk::Widget.default_style.bg(Gtk::STATE_NORMAL)
        widget.modify_bg(Gtk::STATE_NORMAL, (
          selected ? (
            focused ? Gdk::Color.new(65535,65535,0) : Gdk::Color.new(65535,0,0)
          ) : (
            focused ? Gdk::Color.new(0,65535,0) : default_color
          )
        ))
        widget.show
      end

    end

  end

end
