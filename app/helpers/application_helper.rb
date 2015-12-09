module ApplicationHelper

  def truefalse_view(bol)
     [true,'t', '1', 'true','TRUE','T'].include?(bol) ?"Si":"No" # si lo que se pasa es true, devuelve "Si". Si no, devuelve "N""
  end

end
