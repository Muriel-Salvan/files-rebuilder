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
        @gui_controller.open_external(@matching_pointers[0])
      end

      # List of pointers that are represented by this widget
      # list< ( FileInfo | SegmentPointer ) >
      attr_reader :matching_pointers

      # Initialize this matching pointer
      def init_matching_pointers
        @matching_pointers = []
      end

      # Set the pointer widget
      #
      # Parameters::
      # * *pointer_widget* (<em>Gtk::Wiget</em>): The pointer widget to assign
      def set_pointer_widget(pointer_widget)
        @builder['container_frame'] << pointer_widget
      end

      # Add a reference to a FileInfo or a SegmentPointer corresponding to the content of this widget
      #
      # Parameters::
      # * *pointer* (_FileInfo_ or _SegmentPointer_): The pointer referenced by this widget
      # * *message* (_String_): Additional message. nil for none. [default = nil]
      def add_pointer(pointer, message = nil)
        @builder['labels_vbox'] << Gtk::Label.new((pointer.is_a?(Model::FileInfo) ? "#{pointer.get_absolute_name} (#{pointer.segments.size} segments)" : "#{pointer.file_info.get_absolute_name} ##{pointer.idx_segment} (#{pointer.segment.extensions.join(', ')})"))
        @builder['labels_vbox'].show_all
        @matching_pointers << pointer
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
