module FilesRebuilder

  module GUI

    class ComparePointer < GUIHandler

      # Set the pointer to be compared in this widget
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer to be compared
      # * *matching_info* (_MatchingInfo_): Matching information of all files matching this pointer
      # * *matching_selection* (_MatchingSelection_): Current user selection of matching files
      def set_pointer_to_compare(widget, pointer, matching_info, matching_selection)
        get_original_pointer_container(widget).child = @gui_controller.create_widget_for_matching_pointer(pointer, matching_selection.matching_pointers[pointer] == pointer)
        matching_pointers_container = get_matching_pointers_container(widget)
        matching_info.matching_files.sort_by { |_, matching_file_info| matching_file_info.score }.reverse_each do |matching_pointer, matching_file_info|
          matching_pointers_container.child = @gui_controller.create_widget_for_matching_pointer(matching_pointer, matching_selection.matching_pointers[pointer] == matching_pointer)
        end
        # User data
        widget.user_data = {
          :matching_selection => matching_selection,
          :idx_focused => nil
        }
        # First, focus the original one
        set_focused(widget, -1)
      end

      def on_next_match_button_clicked(button_widget)
        widget = get_widget_from_bottom_button(button_widget)
        new_idx_focused = widget.user_data[:idx_focused] + 1
        new_idx_focused = -1 if (new_idx_focused == get_matching_pointers_container(widget).children.size)
        set_focused(widget, new_idx_focused)
      end

      def on_previous_match_button_clicked(button_widget)
        widget = get_widget_from_bottom_button(button_widget)
        new_idx_focused = widget.user_data[:idx_focused] - 1
        new_idx_focused = get_matching_pointers_container(widget).children.size - 1 if (new_idx_focused == -2)
        set_focused(widget, new_idx_focused)
      end

      def on_select_original_button_clicked(button_widget)
        widget = get_widget_from_bottom_button(button_widget)
        select_pointer_widget(widget, get_original_pointer_container(widget).children[0])
      end

      def on_select_matched_button_clicked(button_widget)
        widget = get_widget_from_bottom_button(button_widget)
        idx_focused = widget.user_data[:idx_focused]
        select_pointer_widget(widget, ((idx_focused == -1) ? get_original_pointer_container(widget).children[0] : get_matching_pointers_container(widget).children[idx_focused]))
      end

      # Select a given Matching pointer widget
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # * *matching_pointer_widget* (<em>Gtk::Widget</em>): The MAtching pointer widget
      def select_pointer_widget(widget, matching_pointer_widget)
        original_pointer = get_original_pointer_container(widget).children[0].user_data
        matched_pointer = matching_pointer_widget.user_data
        widget.user_data[:matching_selection].matching_pointers[original_pointer] = matched_pointer
        widget.destroy
      end

      private

      # Get the original pointer container
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # Result::
      # * <em>Gtk::Widget</em>: The pointer container
      def get_original_pointer_container(widget)
        return widget.children[0].children[0].children[0]
      end

      # Get the scrolled window
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # Result::
      # * <em>Gtk::Widget</em>: The scrolled window
      def get_scrolled_window(widget)
        return widget.children[0].children[0].children[1].children[0]
      end

      # Get the matching pointers container
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # Result::
      # * <em>Gtk::Widget</em>: The matching pointers container
      def get_matching_pointers_container(widget)
        return get_scrolled_window(widget).children[0].children[0]
      end

      # Get the ComparePointer widget from a bottom button
      #
      # Parameters::
      # * *button_widget* (<em>Gtk::Widget</em>): The button widget
      # Result::
      # * <em>Gtk::Widget</em>: The ComparePointer widget
      def get_widget_from_bottom_button(button_widget)
        return button_widget.parent.parent.parent
      end

      # Set the focused matching pointer
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # * *idx_focus* (_Fixnum_): The index of the matching pointer (-1: original pointer)
      def set_focused(widget, idx_focus)
        if (widget.user_data[:idx_focused] != idx_focus)
          widget_handler = @gui_factory.get_gui_handler('DisplayMatchingPointer')
          matching_selection = widget.user_data[:matching_selection]
          original_pointer_widget = get_original_pointer_container(widget).children[0]
          original_pointer = original_pointer_widget.user_data
          matching_pointers_container = get_matching_pointers_container(widget)
          # Update the previous one
          if (widget.user_data[:idx_focused] != nil)
            previous_focused_widget = ((widget.user_data[:idx_focused] == -1) ? original_pointer_widget : matching_pointers_container.children[widget.user_data[:idx_focused]])
            widget_handler.set_focus(previous_focused_widget, false, matching_selection.matching_pointers[original_pointer] == previous_focused_widget.user_data)
          end
          # Update the new one
          next_focused_widget = ((idx_focus == -1) ? original_pointer_widget : matching_pointers_container.children[idx_focus])
          widget_handler.set_focus(next_focused_widget, true, matching_selection.matching_pointers[original_pointer] == next_focused_widget.user_data)
          widget.user_data[:idx_focused] = idx_focus
          # Make sure it is visible
          ensure_scroll_visible(widget, idx_focus) if (idx_focus != -1)
        end
      end

      # Ensure that a given matching widget is scroll visible
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ComparePointer widget
      # * *idx_matching_widget* (_Fixnum_): The index of the matching widget
      def ensure_scroll_visible(widget, idx_matching_widget)
        scrolled_window = get_scrolled_window(widget)
        # Get the position of the child widget
        child_y = get_matching_pointers_container(widget).children[idx_matching_widget].allocation.y
        # Scroll the window to make it top
        scrolled_window.vadjustment.value = child_y
      end

    end

  end

end
