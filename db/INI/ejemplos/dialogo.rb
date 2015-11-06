#---
# Excerpted from "FXRuby: Create Lean and Mean GUIs with Ruby",
# published by The Pragmatic Bookshelf.
# Copyrights apply to this code. It may not be used to create training material, 
# courses, books, articles, and the like. Contact us if you are in doubt.
# We make no guarantees that this code is fit for any purpose. 
# Visit http://www.pragmaticprogrammer.com/titles/fxruby for more book information.
#---
require 'fox16'
require 'date'

include Fox



class PreferencesDialog < FXDialogBox

  
  attr_accessor :prefs


  def initialize(owner)
    super(owner, "Preferences", DECOR_TITLE|DECOR_BORDER|DECOR_RESIZE)


    @prefs = {
      :first_name => FXDataTarget.new,
      :last_name => FXDataTarget.new,
      :street => FXDataTarget.new,
      :city => FXDataTarget.new,
      :state => FXDataTarget.new,
      :zip_code => FXDataTarget.new
    }

    add_terminating_buttons
    add_tab_book
  end
  

  def add_terminating_buttons
    buttons = FXHorizontalFrame.new(self,
      :opts => LAYOUT_FILL_X|LAYOUT_SIDE_BOTTOM|PACK_UNIFORM_WIDTH)
    FXButton.new(buttons, "OK",
      :target => self, :selector => FXDialogBox::ID_ACCEPT,
      :opts => BUTTON_NORMAL|LAYOUT_RIGHT)
    FXButton.new(buttons, "Cancel",
      :target => self, :selector => FXDialogBox::ID_CANCEL,
      :opts => BUTTON_NORMAL|LAYOUT_RIGHT)
  end

  

  def add_tab_book


    tabbook = FXTabBook.new(self, :opts => LAYOUT_FILL)


    basics_tab = FXTabItem.new(tabbook, " Basics ")
    basics_page = FXVerticalFrame.new(tabbook,
      :opts => FRAME_RAISED|LAYOUT_FILL)
    contact_tab = FXTabItem.new(tabbook, " Contact ")
    contact_page = FXVerticalFrame.new(tabbook,
      :opts => FRAME_RAISED|LAYOUT_FILL)
    extras_tab = FXTabItem.new(tabbook, " Extras ")
    extras_page = FXVerticalFrame.new(tabbook,
      :opts => FRAME_RAISED|LAYOUT_FILL)


    construct_basics_page(basics_page)
    construct_contact_page(contact_page)
    construct_extras_page(extras_page)

    tabbook.connect(SEL_COMMAND) do |sender, sel, data|
      puts "User selected tab number #{data}"
    end

  end

  

  def construct_basics_page(page)
    form = FXMatrix.new(page, 2,
      :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
    FXLabel.new(form, "First:")
    FXTextField.new(form, 20,
      :target => @prefs[:first_name], :selector => FXDataTarget::ID_VALUE,
      :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "Last:")
    FXTextField.new(form, 20,
      :target => @prefs[:last_name], :selector => FXDataTarget::ID_VALUE,
      :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "Street Address:")
    FXTextField.new(form, 20,
      :target => @prefs[:street], :selector => FXDataTarget::ID_VALUE,
      :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "City:")
    FXTextField.new(form, 20,
      :target => @prefs[:city], :selector => FXDataTarget::ID_VALUE,
      :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "State:")
    states = FXListBox.new(form,
      :target => @prefs[:state], :selector => FXDataTarget::ID_VALUE,
      :opts => (LISTBOX_NORMAL|FRAME_SUNKEN|
                LAYOUT_FILL_X|LAYOUT_FILL_COLUMN))

    add_state_names(states)

    FXLabel.new(form, "Zip Code:")
    FXTextField.new(form, 10,
      :target => @prefs[:zip_code], :selector => FXDataTarget::ID_VALUE,
      :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_COLUMN)
  end

  
  def construct_contact_page(page)
    label_width = 20*6

    phone_groupbox = FXGroupBox.new(page, "Phone Numbers", :opts => GROUPBOX_NORMAL|FRAME_GROOVE|LAYOUT_FILL_X)
    form = FXMatrix.new(phone_groupbox, 2, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
    FXLabel.new(form, "Home Phone:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    FXTextField.new(form, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "Work Phone:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    FXTextField.new(form, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "Cell Phone:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    FXTextField.new(form, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)

    web_groupbox = FXGroupBox.new(page, "Web", :opts => GROUPBOX_NORMAL|FRAME_GROOVE|LAYOUT_FILL_X)
    form = FXMatrix.new(web_groupbox, 2, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
    FXLabel.new(form, "E-mail:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    FXTextField.new(form, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
    FXLabel.new(form, "Web Site:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    FXTextField.new(form, 20, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_X|LAYOUT_FILL_COLUMN)
  end
  
  def construct_extras_page(page)
    label_width = 20*6

    birthdate_groupbox = FXGroupBox.new(page, "Birthdate", :opts => GROUPBOX_NORMAL|FRAME_GROOVE|LAYOUT_FILL_X)
    form = FXMatrix.new(birthdate_groupbox, 2, :opts => MATRIX_BY_COLUMNS|LAYOUT_FILL_X)
    FXLabel.new(form, "Month:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    months = FXListBox.new(form, :opts => LISTBOX_NORMAL|FRAME_SUNKEN|LAYOUT_FILL_COLUMN)
    Date::MONTHNAMES.each { |monthname| months.appendItem(monthname) unless monthname.nil? }
    months.numVisible = 6
    FXLabel.new(form, "Day:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    days = FXListBox.new(form, :opts => LISTBOX_NORMAL|FRAME_SUNKEN|LAYOUT_FILL_COLUMN)
    1.upto(31) { |day| days.appendItem(day.to_s) }
    days.numVisible = 6
    months.connect(SEL_COMMAND) do |sender, sel, data|
      days.clearItems
      1.upto(days_per_month(sender.getItemText(data))) { |day| days.appendItem(day.to_s) }
    end
    FXLabel.new(form, "Year:", :opts => LABEL_NORMAL|LAYOUT_FIX_WIDTH|JUSTIFY_LEFT, :width => label_width)
    FXTextField.new(form, 6, :opts => TEXTFIELD_NORMAL|LAYOUT_FILL_COLUMN)
  end
  
  def add_state_names(listbox)
    listbox.appendItem("Alabama")
    listbox.appendItem("Florida")
    listbox.appendItem("Georgia")
  end
  
  def days_per_month(month)
    case month
    when "January", "March", "May", "July", "August", "October", "December"
      31
    when "April", "June", "September", "November"
      30
    when "February"
      28
    end
  end

end



class TabBookExample < FXMainWindow

  attr_accessor :user_name
  attr_accessor :user_address

  def initialize(app)
    super(app, "Tabbed Notebook", :width => 400, :height => 200)
    Struct.new("Name", :first_name, :last_name)
    @user_name = Struct::Name.new("Igor", "Stravinsky")
    Struct.new("Address", :street, :city, :state, :zip_code)
    @user_address = Struct::Address.new("1910 Firebird St.", "Remlap", "Alabama", "35133")
    menu_bar = FXMenuBar.new(self, :opts => LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
    file_menu_pane = FXMenuPane.new(self)

    prefs_command = FXMenuCommand.new(file_menu_pane, "Preferences...")
    prefs_command.connect(SEL_COMMAND) do

      dialog = PreferencesDialog.new(self)


      dialog.prefs[:first_name].value = user_name.first_name
      dialog.prefs[:last_name].value  = user_name.last_name
      dialog.prefs[:street].value     = user_address.street
      dialog.prefs[:city].value       = user_address.city
      dialog.prefs[:state].value      = user_address.state
      dialog.prefs[:zip_code].value   = user_address.zip_code


      if dialog.execute != 0
        user_name.first_name  = dialog.prefs[:first_name].value
        user_name.last_name   = dialog.prefs[:last_name].value
        user_address.street   = dialog.prefs[:street].value
        user_address.city     = dialog.prefs[:city].value
        user_address.state    = dialog.prefs[:state].value
        user_address.zip_code = dialog.prefs[:zip_code].value
      end

    end

    file_menu_title = FXMenuTitle.new(menu_bar, "File", :popupMenu => file_menu_pane)
  end
  
  def create
    super
    show(PLACEMENT_SCREEN)
  end
end

if __FILE__ == $0
  FXApp.new do |app|
    TabBookExample.new(app)
    app.create
    app.run
  end
end